// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YAFA';

  @override
  String get navRecords => 'Records';

  @override
  String get navStats => 'Statistics';

  @override
  String get navSettings => 'Settings';

  @override
  String get expense => 'Expense';

  @override
  String get income => 'Income';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get amount => 'Amount';

  @override
  String get category => 'Category';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get invalidAmount => 'Enter a valid amount';

  @override
  String get pickCategory => 'Please choose a category';

  @override
  String get noCategoriesOfType =>
      'No categories of this type. Add one in Settings > Categories.';

  @override
  String get addRecord => 'Add record';

  @override
  String get noRecordsThisMonth => 'No records this month.';

  @override
  String get newRecord => 'New record';

  @override
  String get editRecord => 'Edit record';

  @override
  String get deleteRecordQuestion => 'Delete this record?';

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get categories => 'Categories';

  @override
  String get addCategory => 'Add category';

  @override
  String get noCategoriesYet => 'No categories yet.';

  @override
  String get archived => 'Archived';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String deleteCategoryQuestion(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteCategoryWarning =>
      'ALL records and recurring transactions in this category will be deleted too. Archive the category instead to keep its records.';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'A name is required';

  @override
  String get nameTaken => 'A category with this name already exists';

  @override
  String get emojiOptional => 'Emoji (optional, shown instead of the icon)';

  @override
  String get colour => 'Colour';

  @override
  String get icon => 'Icon';

  @override
  String get archive => 'Archive';

  @override
  String get archiveHint =>
      'Hidden for new records; existing records are kept.';

  @override
  String get recurringTransactions => 'Recurring transactions';

  @override
  String get recurringEmpty =>
      'Add regular transactions such as rent, salary or subscriptions and they will be recorded automatically when due.';

  @override
  String get finished => 'Finished';

  @override
  String nextOn(String date) {
    return 'Next: $date';
  }

  @override
  String get newRecurring => 'New recurring transaction';

  @override
  String get editRecurring => 'Edit recurring transaction';

  @override
  String get deleteRecurringQuestion => 'Delete this recurring transaction?';

  @override
  String get deleteRecurringHint =>
      'Records already created are kept; only new ones stop.';

  @override
  String get recurringTitleHint => 'Title (e.g. Rent, Netflix)';

  @override
  String get every => 'Every';

  @override
  String get start => 'Start';

  @override
  String get endOptional => 'End (optional)';

  @override
  String get noEnd => 'No end date';

  @override
  String get removeEnd => 'Remove end date';

  @override
  String pastRecordsCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count past records were created automatically',
      one: '1 past record was created automatically',
    );
    return '$_temp0';
  }

  @override
  String unitDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String unitWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String unitMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String unitYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get everyDay => 'Every day';

  @override
  String get everyWeek => 'Every week';

  @override
  String get everyMonth => 'Every month';

  @override
  String get everyYear => 'Every year';

  @override
  String everyN(int count, String unit) {
    return 'Every $count $unit';
  }

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get noDataForPeriod => 'No data for this period.';

  @override
  String get total => 'Total';

  @override
  String get daily => 'Daily';

  @override
  String get monthly => 'Monthly';

  @override
  String get settings => 'Settings';

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String ruleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String get currency => 'Currency';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get importOinkoin => 'Import Oinkoin backup';

  @override
  String get importOinkoinHint =>
      'The .json file from Oinkoin > Settings > Backup';

  @override
  String get pickOinkoinBackup => 'Choose the Oinkoin backup';

  @override
  String importDone(
    int records,
    int transfers,
    int categories,
    int wallets,
    int rules,
  ) {
    return 'Imported $records records, $transfers transfers, $categories categories, $wallets wallets and $rules recurring transactions.';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records already existed.',
      one: '1 record already existed.',
    );
    return '$_temp0';
  }

  @override
  String get importNotJson => 'The file is not valid JSON.';

  @override
  String get importNotOinkoin =>
      'This file does not look like an Oinkoin backup.';

  @override
  String get importNotUtf8 => 'The file could not be read (not UTF-8).';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get aboutLegalese =>
      'Yet Another Finance App\nAll your data stays on your device.';

  @override
  String get wallet => 'Wallet';

  @override
  String get wallets => 'Wallets';

  @override
  String get allWallets => 'All wallets';

  @override
  String get addWallet => 'Add wallet';

  @override
  String get newWallet => 'New wallet';

  @override
  String get editWallet => 'Edit wallet';

  @override
  String walletCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets',
      one: '1 wallet',
    );
    return '$_temp0';
  }

  @override
  String get startingBalance => 'Starting balance';

  @override
  String get startingBalanceHint =>
      'Use a minus sign for debt, e.g. a credit card';

  @override
  String get invalidBalance => 'Enter a valid balance';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get walletArchiveHint =>
      'Hidden when adding records; its history and balance are kept.';

  @override
  String deleteWalletQuestion(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get walletInUse =>
      'This wallet has records, transfers or recurring transactions. Archive it instead.';

  @override
  String get lastWallet => 'You need at least one wallet.';

  @override
  String get transfer => 'Transfer';

  @override
  String get fromWallet => 'From';

  @override
  String get toWallet => 'To';

  @override
  String get sameWallet => 'Choose two different wallets';

  @override
  String get newTransfer => 'New transfer';

  @override
  String get editTransfer => 'Edit transfer';

  @override
  String get deleteTransferQuestion => 'Delete this transfer?';

  @override
  String get needTwoWallets =>
      'Add a second wallet in Settings > Wallets to make transfers.';

  @override
  String get moneyIn => 'Money in';

  @override
  String get moneyOut => 'Money out';

  @override
  String get net => 'Net';

  @override
  String transferToWallet(String name) {
    return 'To $name';
  }

  @override
  String transferFromWallet(String name) {
    return 'From $name';
  }

  @override
  String get manage => 'Manage';

  @override
  String get recurringShort => 'Recurring';

  @override
  String get pickMonth => 'Choose month';

  @override
  String get pickYear => 'Choose year';

  @override
  String get backupCreate => 'Back up';

  @override
  String get backupCreateHint =>
      'Save all your data to a file, e.g. on Google Drive';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupRestoreHint => 'Replaces all current data';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get backupPick => 'Choose a YAFA backup';

  @override
  String get backupRestoreQuestion => 'Restore this backup?';

  @override
  String backupRestoreDetails(
    String date,
    int wallets,
    int records,
    int transfers,
    int rules,
  ) {
    return 'Backup from $date: $wallets wallets, $records records, $transfers transfers, $rules recurring transactions.\n\nAll current data will be replaced. This cannot be undone.';
  }

  @override
  String get backupRestoreConfirm => 'Restore';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupNotBackup => 'This file is not a YAFA backup.';

  @override
  String get backupNewer =>
      'This backup was made by a newer version of YAFA. Update the app first.';

  @override
  String get unknownDate => 'an unknown date';

  @override
  String get autoBackup => 'Automatic backup';

  @override
  String get autoBackupOff => 'Off';

  @override
  String get autoBackupDaily => 'Daily';

  @override
  String get autoBackupWeekly => 'Weekly';

  @override
  String get autoBackupMonthly => 'Monthly';

  @override
  String get autoBackupOffHint =>
      'When on, a backup is saved to Download/YAFA when you open the app; the last 5 are kept';

  @override
  String autoBackupLast(String date) {
    return 'Last: $date';
  }

  @override
  String get autoBackupNever => 'No automatic backup yet';

  @override
  String autoBackupFailed(String error) {
    return 'Last automatic backup failed: $error';
  }

  @override
  String get exportCsv => 'Export as CSV';

  @override
  String get exportCsvHint =>
      'All records and transfers, for Excel or Google Sheets';

  @override
  String get exportCsvSaved => 'CSV saved';

  @override
  String get csvDate => 'Date';

  @override
  String get csvType => 'Type';

  @override
  String get csvToWallet => 'To wallet';

  @override
  String get csvTitle => 'Title';

  @override
  String get csvNote => 'Note';
}
