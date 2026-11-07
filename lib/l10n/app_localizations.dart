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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'YAFA'**
  String get appTitle;

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

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

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

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String categoryCount(int count);

  /// No description provided for @ruleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String ruleCount(int count);

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
  /// **'Yet Another Financial App\nAll your data stays on your device.'**
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

  /// No description provided for @walletCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wallet} other{{count} wallets}}'**
  String walletCount(int count);

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

  /// No description provided for @needTwoWallets.
  ///
  /// In en, this message translates to:
  /// **'Add a second wallet in Settings > Wallets to make transfers.'**
  String get needTwoWallets;

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
