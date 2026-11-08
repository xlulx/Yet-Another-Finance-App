import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/recurring_rule.dart';
import '../utils/money.dart';
import 'recurrence.dart';

/// Settings keys.
const remindRecurringKey = 'remind_recurring';
const remindDebtsKey = 'remind_debts';
const remindTimeKey = 'remind_time';

/// How far ahead reminders are scheduled. They are rescheduled whenever the
/// app opens or data changes, so this only matters if it stays closed.
const reminderHorizon = Duration(days: 45);

/// One notification: everything due on one day, shown at the chosen time.
class Reminder {
  const Reminder(this.when, this.title, this.body);

  final DateTime when;
  final String title;

  /// Null when [title] says it all.
  final String? body;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.when == when &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(when, title, body);
}

/// The reminders to schedule after [now]: recurring records on the days they
/// are added, and open debts on their due date. Everything on one day goes
/// into one notification, at [hour]:[minute].
List<Reminder> upcomingReminders({
  required DateTime now,
  required int hour,
  required int minute,
  required AppLocalizations l,
  required String currency,
  Iterable<RecurringRule> rules = const [],
  Map<int, Category> categories = const {},
  Iterable<Debt> debts = const [],
  int Function(Debt)? remainingOf,
  bool Function(Debt)? isSettled,
}) {
  final until = now.add(reminderHorizon);
  final byDay = <DateTime, List<String>>{};
  void add(DateTime date, String line) {
    final at = DateTime(date.year, date.month, date.day, hour, minute);
    if (!at.isAfter(now) || at.isAfter(until)) return;
    byDay.putIfAbsent(at, () => []).add(line);
  }

  for (final rule in rules) {
    if (rule.interval < 1) continue;
    final category = categories[rule.categoryId];
    final name = rule.title.isNotEmpty ? rule.title : category?.name ?? '';
    final amount = formatMoney(
      category?.type == CategoryType.income ? rule.amount : -rule.amount,
      currency,
      signed: true,
      locale: l.localeName,
    );
    for (var n = 0; n < 5000; n++) {
      final date = nthOccurrence(rule, n);
      if (date.isAfter(until)) break;
      if (rule.endDate != null && date.isAfter(rule.endDate!)) break;
      add(date, l.reminderRecurring(name, amount));
    }
  }

  for (final d in debts) {
    final due = d.dueDate;
    if (due == null || (isSettled?.call(d) ?? d.closed)) continue;
    final amount = formatMoney(
      remainingOf?.call(d) ?? d.amount,
      currency,
      locale: l.localeName,
    );
    add(
      due,
      d.lent
          ? l.reminderDebtLent(d.person, amount)
          : l.reminderDebtBorrowed(d.person, amount),
    );
  }

  return [
    for (final MapEntry(key: at, value: lines) in byDay.entries)
      lines.length == 1
          ? Reminder(at, lines.single, null)
          : Reminder(at, l.reminderCount(lines.length), lines.join('\n')),
  ]..sort((a, b) => a.when.compareTo(b.when));
}

/// Shows [Reminder]s at their time, even when the app is closed.
abstract class ReminderScheduler {
  const ReminderScheduler();

  /// Asks for permission to show notifications; returns whether granted.
  Future<bool> requestPermission();

  /// Cancels all scheduled reminders and schedules [reminders] instead.
  Future<void> replaceAll(List<Reminder> reminders, AppLocalizations l);
}

/// Does nothing; for tests and platforms without notifications.
class NoReminderScheduler extends ReminderScheduler {
  const NoReminderScheduler();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<Reminder> reminders, AppLocalizations l) async {}
}

/// Android notifications.
class PlatformReminderScheduler extends ReminderScheduler {
  PlatformReminderScheduler();

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      )
      .then((_) {});

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders, AppLocalizations l) async {
    await _init();
    await _plugin.cancelAll();
    for (final (i, r) in reminders.indexed) {
      await _plugin.zonedSchedule(
        id: i,
        // The local wall-clock time, as an instant; no time zone database
        // needed for one-off notifications.
        scheduledDate: tz.TZDateTime.from(r.when, tz.UTC),
        title: r.title,
        body: r.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            l.reminders,
            styleInformation: r.body == null
                ? null
                : BigTextStyleInformation(r.body!),
          ),
        ),
        // Inexact: needs no special permission; a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
