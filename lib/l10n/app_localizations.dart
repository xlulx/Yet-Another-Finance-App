import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get navRecords;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStats;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get invalidAmount;

  /// No description provided for @pickCategory.
  ///
  /// In en, this message translates to:
  /// **'Please choose a category'**
  String get pickCategory;

  /// No description provided for @noCategoriesOfType.
  ///
  /// In en, this message translates to:
  /// **'No categories of this type. Add one in Settings > Categories.'**
  String get noCategoriesOfType;

  /// No description provided for @addRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get addRecord;

  /// No description provided for @noRecordsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No records this month.'**
  String get noRecordsThisMonth;

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get newRecord;

  /// No description provided for @editRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecord;

  /// No description provided for @deleteRecordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get deleteRecordQuestion;

  /// No description provided for @titleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get titleOptional;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get noCategoriesYet;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @deleteCategoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCategoryQuestion(String name);

  /// No description provided for @deleteCategoryWarning.
  ///
  /// In en, this message translates to:
  /// **'ALL records and recurring transactions in this category will be deleted too. Archive the category instead to keep its records.'**
  String get deleteCategoryWarning;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'A name is required'**
  String get nameRequired;

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists'**
  String get nameTaken;

  /// No description provided for @emojiOptional.
  ///
  /// In en, this message translates to:
  /// **'Emoji (optional, shown instead of the icon)'**
  String get emojiOptional;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden for new records; existing records are kept.'**
  String get archiveHint;

  /// No description provided for @recurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get recurringTransactions;

  /// No description provided for @recurringEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add regular transactions such as rent, salary or subscriptions and they will be recorded automatically when due.'**
  String get recurringEmpty;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @nextOn.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String nextOn(String date);

  /// No description provided for @newRecurring.
  ///
  /// In en, this message translates to:
  /// **'New recurring transaction'**
  String get newRecurring;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring transaction'**
  String get editRecurring;

  /// No description provided for @deleteRecurringQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring transaction?'**
  String get deleteRecurringQuestion;

  /// No description provided for @deleteRecurringHint.
  ///
  /// In en, this message translates to:
  /// **'Records already created are kept; only new ones stop.'**
  String get deleteRecurringHint;

  /// No description provided for @recurringTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title (e.g. Rent, Netflix)'**
  String get recurringTitleHint;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @endOptional.
  ///
  /// In en, this message translates to:
  /// **'End (optional)'**
  String get endOptional;

  /// No description provided for @noEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEnd;

  /// No description provided for @removeEnd.
  ///
  /// In en, this message translates to:
  /// **'Remove end date'**
  String get removeEnd;

  /// No description provided for @pastRecordsCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 past record was created automatically} other{{count} past records were created automatically}}'**
  String pastRecordsCreated(int count);

  /// No description provided for @unitDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String unitDay(int count);

  /// No description provided for @unitWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week} other{weeks}}'**
  String unitWeek(int count);

  /// No description provided for @unitMonth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{month} other{months}}'**
  String unitMonth(int count);

  /// No description provided for @unitYear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{year} other{years}}'**
  String unitYear(int count);

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get everyWeek;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @everyYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get everyYear;

  /// No description provided for @everyN.
  ///
  /// In en, this message translates to:
  /// **'Every {count} {unit}'**
  String everyN(int count, String unit);

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @noDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period.'**
  String get noDataForPeriod;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @importOinkoin.
  ///
  /// In en, this message translates to:
  /// **'Import Oinkoin backup'**
  String get importOinkoin;

  /// No description provided for @importOinkoinHint.
  ///
  /// In en, this message translates to:
  /// **'The .json file from Oinkoin > Settings > Backup'**
  String get importOinkoinHint;

  /// No description provided for @pickOinkoinBackup.
  ///
  /// In en, this message translates to:
  /// **'Choose the Oinkoin backup'**
  String get pickOinkoinBackup;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {records} records, {transfers} transfers, {categories} categories, {wallets} wallets and {rules} recurring transactions.'**
  String importDone(
    int records,
    int transfers,
    int categories,
    int wallets,
    int rules,
  );

  /// No description provided for @importSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record already existed.} other{{count} records already existed.}}'**
  String importSkipped(int count);

  /// No description provided for @importNotJson.
  ///
  /// In en, this message translates to:
  /// **'The file is not valid JSON.'**
  String get importNotJson;

  /// No description provided for @importNotOinkoin.
  ///
  /// In en, this message translates to:
  /// **'This file does not look like an Oinkoin backup.'**
  String get importNotOinkoin;

  /// No description provided for @importNotUtf8.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read (not UTF-8).'**
  String get importNotUtf8;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'A simple, private budget tracker.\nAll your data stays on your device.'**
  String get aboutLegalese;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @wallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get wallets;

  /// No description provided for @allWallets.
  ///
  /// In en, this message translates to:
  /// **'All wallets'**
  String get allWallets;

  /// No description provided for @addWallet.
  ///
  /// In en, this message translates to:
  /// **'Add wallet'**
  String get addWallet;

  /// No description provided for @newWallet.
  ///
  /// In en, this message translates to:
  /// **'New wallet'**
  String get newWallet;

  /// No description provided for @editWallet.
  ///
  /// In en, this message translates to:
  /// **'Edit wallet'**
  String get editWallet;

  /// No description provided for @startingBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting balance'**
  String get startingBalance;

  /// No description provided for @startingBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Use a minus sign for debt, e.g. a credit card'**
  String get startingBalanceHint;

  /// No description provided for @invalidBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid balance'**
  String get invalidBalance;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @walletArchiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden when adding records; its history and balance are kept.'**
  String get walletArchiveHint;

  /// No description provided for @deleteWalletQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteWalletQuestion(String name);

  /// No description provided for @walletInUse.
  ///
  /// In en, this message translates to:
  /// **'This wallet has records, transfers or recurring transactions. Archive it instead.'**
  String get walletInUse;

  /// No description provided for @lastWallet.
  ///
  /// In en, this message translates to:
  /// **'You need at least one wallet.'**
  String get lastWallet;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @fromWallet.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromWallet;

  /// No description provided for @toWallet.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toWallet;

  /// No description provided for @sameWallet.
  ///
  /// In en, this message translates to:
  /// **'Choose two different wallets'**
  String get sameWallet;

  /// No description provided for @newTransfer.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get newTransfer;

  /// No description provided for @editTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransfer;

  /// No description provided for @deleteTransferQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this transfer?'**
  String get deleteTransferQuestion;

  /// No description provided for @moneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get moneyIn;

  /// No description provided for @moneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get moneyOut;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @transferToWallet.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String transferToWallet(String name);

  /// No description provided for @transferFromWallet.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String transferFromWallet(String name);

  /// No description provided for @pickMonth.
  ///
  /// In en, this message translates to:
  /// **'Choose month'**
  String get pickMonth;

  /// No description provided for @pickYear.
  ///
  /// In en, this message translates to:
  /// **'Choose year'**
  String get pickYear;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get backupCreate;

  /// No description provided for @backupCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Save all your data to a file, e.g. on Google Drive'**
  String get backupCreateHint;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces all current data'**
  String get backupRestoreHint;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @backupPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a YASBA backup'**
  String get backupPick;

  /// No description provided for @backupRestoreQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get backupRestoreQuestion;

  /// No description provided for @backupRestoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}: {wallets} wallets, {records} records, {transfers} transfers, {rules} recurring transactions.\n\nAll current data will be replaced. This cannot be undone.'**
  String backupRestoreDetails(
    String date,
    int wallets,
    int records,
    int transfers,
    int rules,
  );

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backupNotBackup.
  ///
  /// In en, this message translates to:
  /// **'This file is not a YASBA backup.'**
  String get backupNotBackup;

  /// No description provided for @backupNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of YASBA. Update the app first.'**
  String get backupNewer;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'an unknown date'**
  String get unknownDate;

  /// No description provided for @autoBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get autoBackup;

  /// No description provided for @autoBackupOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get autoBackupOff;

  /// No description provided for @autoBackupDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get autoBackupDaily;

  /// No description provided for @autoBackupWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get autoBackupWeekly;

  /// No description provided for @autoBackupMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get autoBackupMonthly;

  /// No description provided for @autoBackupOffHint.
  ///
  /// In en, this message translates to:
  /// **'When on, a backup is saved to Documents/YASBA when you open the app; the last 5 are kept'**
  String get autoBackupOffHint;

  /// No description provided for @autoBackupLast.
  ///
  /// In en, this message translates to:
  /// **'Last: {date}'**
  String autoBackupLast(String date);

  /// No description provided for @autoBackupNever.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup yet'**
  String get autoBackupNever;

  /// No description provided for @autoBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Last automatic backup failed: {error}'**
  String autoBackupFailed(String error);

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvHint.
  ///
  /// In en, this message translates to:
  /// **'All records, transfers and debts, for Excel or Google Sheets'**
  String get exportCsvHint;

  /// No description provided for @exportCsvSaved.
  ///
  /// In en, this message translates to:
  /// **'CSV saved'**
  String get exportCsvSaved;

  /// No description provided for @csvDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get csvDate;

  /// No description provided for @csvType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get csvType;

  /// No description provided for @csvToWallet.
  ///
  /// In en, this message translates to:
  /// **'To wallet'**
  String get csvToWallet;

  /// No description provided for @csvTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get csvTitle;

  /// No description provided for @csvNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get csvNote;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'A simple, private budget tracker'**
  String get tagline;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// No description provided for @owedToMe.
  ///
  /// In en, this message translates to:
  /// **'Owed to me'**
  String get owedToMe;

  /// No description provided for @iOwe.
  ///
  /// In en, this message translates to:
  /// **'I owe'**
  String get iOwe;

  /// No description provided for @addDebt.
  ///
  /// In en, this message translates to:
  /// **'Add debt'**
  String get addDebt;

  /// No description provided for @newDebt.
  ///
  /// In en, this message translates to:
  /// **'New debt'**
  String get newDebt;

  /// No description provided for @editDebt.
  ///
  /// In en, this message translates to:
  /// **'Edit debt'**
  String get editDebt;

  /// No description provided for @debtLent.
  ///
  /// In en, this message translates to:
  /// **'I lent'**
  String get debtLent;

  /// No description provided for @debtBorrowed.
  ///
  /// In en, this message translates to:
  /// **'I borrowed'**
  String get debtBorrowed;

  /// No description provided for @person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @personRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get personRequired;

  /// No description provided for @dueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get dueDateOptional;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @removeDueDate.
  ///
  /// In en, this message translates to:
  /// **'Remove due date'**
  String get removeDueDate;

  /// No description provided for @noWallet.
  ///
  /// In en, this message translates to:
  /// **'No wallet (don\'t change balances)'**
  String get noWallet;

  /// No description provided for @debtsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Note money you lend or borrow, and record repayments as they come. Debts change wallet balances but are not income or expenses.'**
  String get debtsEmpty;

  /// No description provided for @openDebts.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openDebts;

  /// No description provided for @settledDebts.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settledDebts;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// No description provided for @remainingOf.
  ///
  /// In en, this message translates to:
  /// **'{remaining} left of {total}'**
  String remainingOf(String remaining, String total);

  /// No description provided for @debtLentEvent.
  ///
  /// In en, this message translates to:
  /// **'Lent'**
  String get debtLentEvent;

  /// No description provided for @debtBorrowedEvent.
  ///
  /// In en, this message translates to:
  /// **'Borrowed'**
  String get debtBorrowedEvent;

  /// No description provided for @repaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Repayment received'**
  String get repaymentReceived;

  /// No description provided for @repaymentMade.
  ///
  /// In en, this message translates to:
  /// **'Repayment made'**
  String get repaymentMade;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get addPayment;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @noPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get noPayments;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @closeDebt.
  ///
  /// In en, this message translates to:
  /// **'Mark as settled'**
  String get closeDebt;

  /// No description provided for @reopenDebt.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopenDebt;

  /// No description provided for @deleteDebtQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this debt and its payments?'**
  String get deleteDebtQuestion;

  /// No description provided for @deletePaymentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this payment?'**
  String get deletePaymentQuestion;

  /// No description provided for @theyOweMe.
  ///
  /// In en, this message translates to:
  /// **'{name} owes you'**
  String theyOweMe(String name);

  /// No description provided for @iOweThem.
  ///
  /// In en, this message translates to:
  /// **'You owe {name}'**
  String iOweThem(String name);

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @paymentTooBig.
  ///
  /// In en, this message translates to:
  /// **'At most {amount}'**
  String paymentTooBig(String amount);

  /// No description provided for @debtSlice.
  ///
  /// In en, this message translates to:
  /// **'Debt: {name}'**
  String debtSlice(String name);

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @remindersHint.
  ///
  /// In en, this message translates to:
  /// **'A notification on the day, even when the app is closed'**
  String get remindersHint;

  /// No description provided for @remindRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring records'**
  String get remindRecurring;

  /// No description provided for @remindDebts.
  ///
  /// In en, this message translates to:
  /// **'Debt due dates'**
  String get remindDebts;

  /// No description provided for @remindTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get remindTime;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for YASBA in Android settings'**
  String get notificationsDenied;

  /// No description provided for @reminderRecurring.
  ///
  /// In en, this message translates to:
  /// **'{name} {amount} · recurring'**
  String reminderRecurring(String name, String amount);

  /// No description provided for @reminderDebtLent.
  ///
  /// In en, this message translates to:
  /// **'{name} is due to pay you {amount}'**
  String reminderDebtLent(String name, String amount);

  /// No description provided for @reminderDebtBorrowed.
  ///
  /// In en, this message translates to:
  /// **'You are due to pay {name} {amount}'**
  String reminderDebtBorrowed(String name, String amount);

  /// No description provided for @reminderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reminders for today'**
  String reminderCount(int count);

  /// No description provided for @closedUncollected.
  ///
  /// In en, this message translates to:
  /// **'Not collected'**
  String get closedUncollected;

  /// No description provided for @closedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Not paid back'**
  String get closedUnpaid;

  /// No description provided for @closedUncollectedEvent.
  ///
  /// In en, this message translates to:
  /// **'Closed, not collected'**
  String get closedUncollectedEvent;

  /// No description provided for @closedUnpaidEvent.
  ///
  /// In en, this message translates to:
  /// **'Closed, not paid back'**
  String get closedUnpaidEvent;

  /// No description provided for @closeDebtQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close this debt?'**
  String get closeDebtQuestion;

  /// No description provided for @closeDebtLossHint.
  ///
  /// In en, this message translates to:
  /// **'The remaining {amount} will not come back and counts as an expense.'**
  String closeDebtLossHint(String amount);

  /// No description provided for @closeDebtGainHint.
  ///
  /// In en, this message translates to:
  /// **'The remaining {amount} will not be paid and counts as income.'**
  String closeDebtGainHint(String amount);

  /// No description provided for @closedDifference.
  ///
  /// In en, this message translates to:
  /// **'Written off'**
  String get closedDifference;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to YASBA'**
  String get welcomeTitle;

  /// No description provided for @welcomeText.
  ///
  /// In en, this message translates to:
  /// **'Keep track of your income, expenses and debts with ease. No account, no ads: all your data stays on your phone.'**
  String get welcomeText;

  /// No description provided for @readyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get readyTitle;

  /// No description provided for @readyText.
  ///
  /// In en, this message translates to:
  /// **'Add your first income or expense with the Add record button.'**
  String get readyText;

  /// No description provided for @haveBackup.
  ///
  /// In en, this message translates to:
  /// **'Used YASBA on another phone? Bring your data over from a backup.'**
  String get haveBackup;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @featuresTitle.
  ///
  /// In en, this message translates to:
  /// **'What you can do'**
  String get featuresTitle;

  /// No description provided for @featureRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Income and expenses'**
  String get featureRecordsTitle;

  /// No description provided for @featureRecordsText.
  ///
  /// In en, this message translates to:
  /// **'See where your money goes, day by day'**
  String get featureRecordsText;

  /// No description provided for @featureWalletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get featureWalletsTitle;

  /// No description provided for @featureWalletsText.
  ///
  /// In en, this message translates to:
  /// **'Cash, bank accounts and cards, with transfers between them'**
  String get featureWalletsText;

  /// No description provided for @featureDebtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get featureDebtsTitle;

  /// No description provided for @featureDebtsText.
  ///
  /// In en, this message translates to:
  /// **'Keep track of money you lent and borrowed'**
  String get featureDebtsText;

  /// No description provided for @featureStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get featureStatsTitle;

  /// No description provided for @featureStatsText.
  ///
  /// In en, this message translates to:
  /// **'Charts by category, month and year'**
  String get featureStatsText;

  /// No description provided for @featureRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get featureRecurringTitle;

  /// No description provided for @featureRecurringText.
  ///
  /// In en, this message translates to:
  /// **'Rent, salary and subscriptions added for you, with reminders if you like'**
  String get featureRecurringText;

  /// No description provided for @featureBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get featureBackupTitle;

  /// No description provided for @featureBackupText.
  ///
  /// In en, this message translates to:
  /// **'Save all your data to one file, or export it as CSV'**
  String get featureBackupText;

  /// No description provided for @periodLast3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get periodLast3Months;

  /// No description provided for @periodLast12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get periodLast12Months;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get periodCustom;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @incomeAndExpense.
  ///
  /// In en, this message translates to:
  /// **'Income and expenses'**
  String get incomeAndExpense;

  /// No description provided for @last12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get last12Months;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records in this category for the period.'**
  String get categoryEmpty;

  /// No description provided for @recordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}}'**
  String recordCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
