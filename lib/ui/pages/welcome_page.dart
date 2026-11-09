import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../utils/money.dart';
import '../restore_backup.dart';

/// Shown once, on a fresh install: language and currency, what the app
/// does, and a way to restore a backup instead.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _pageCount = 3;

  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() => context.read<AppState>().finishOnboarding();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Step(
                    icon: Icons.account_balance_wallet,
                    title: l.welcomeTitle,
                    text: l.welcomeText,
                    children: [
                      _Choice(
                        label: l.language,
                        value: state.language,
                        items: {
                          '': l.languageSystem,
                          // Language names are shown in their own language.
                          'en': 'English',
                          'tr': 'Türkçe',
                        },
                        onChanged: state.setLanguage,
                      ),
                      _Choice(
                        label: l.currency,
                        value: currencySymbols.contains(state.currency)
                            ? state.currency
                            : null,
                        items: {for (final c in currencySymbols) c: c},
                        onChanged: state.setCurrency,
                      ),
                    ],
                  ),
                  _Step(
                    icon: Icons.auto_awesome,
                    title: l.featuresTitle,
                    children: [
                      for (final (icon, title, text) in [
                        (
                          Icons.receipt_long,
                          l.featureRecordsTitle,
                          l.featureRecordsText,
                        ),
                        (
                          Icons.account_balance_wallet_outlined,
                          l.featureWalletsTitle,
                          l.featureWalletsText,
                        ),
                        (
                          Icons.handshake_outlined,
                          l.featureDebtsTitle,
                          l.featureDebtsText,
                        ),
                        (
                          Icons.pie_chart_outline,
                          l.featureStatsTitle,
                          l.featureStatsText,
                        ),
                        (
                          Icons.repeat,
                          l.featureRecurringTitle,
                          l.featureRecurringText,
                        ),
                        (
                          Icons.backup_outlined,
                          l.featureBackupTitle,
                          l.featureBackupText,
                        ),
                      ])
                        _Feature(icon: icon, title: title, text: text),
                    ],
                  ),
                  _Step(
                    icon: Icons.check_circle_outline,
                    title: l.readyTitle,
                    text: l.readyText,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        l.haveBackup,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings_backup_restore),
                        label: Text(l.backupRestore),
                        // Restoring also ends the welcome screen.
                        onPressed: () => restoreBackupFromFile(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: _page == 0
                        ? null
                        : TextButton(
                            onPressed: () => _go(_page - 1),
                            child: Text(l.back),
                          ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: last ? _finish : () => _go(_page + 1),
                      child: Text(last ? l.getStarted : l.next),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page: a big icon, a title, a short text and the page's controls.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    this.text,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 24),
      children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A9A84), Color(0xFF1F5E50)],
              ),
            ),
            child: Icon(icon, size: 56, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: 12),
          Text(
            text!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 32),
        for (final c in children)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ],
    );
  }
}

/// One feature in the list: an icon, a name and a line about it.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(icon, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled drop-down, for the language and currency.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final MapEntry(:key, value: text) in items.entries)
          DropdownMenuItem(value: key, child: Text(text)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
