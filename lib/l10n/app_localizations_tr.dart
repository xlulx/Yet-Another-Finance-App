// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'YASBA';

  @override
  String get navRecords => 'Kayıtlar';

  @override
  String get navStats => 'İstatistik';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get expense => 'Gider';

  @override
  String get income => 'Gelir';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get delete => 'Sil';

  @override
  String get add => 'Ekle';

  @override
  String get previous => 'Önceki';

  @override
  String get next => 'Sonraki';

  @override
  String get amount => 'Tutar';

  @override
  String get category => 'Kategori';

  @override
  String get noteOptional => 'Not (isteğe bağlı)';

  @override
  String get invalidAmount => 'Geçerli bir tutar girin';

  @override
  String get pickCategory => 'Lütfen bir kategori seçin';

  @override
  String get noCategoriesOfType =>
      'Bu türde kategori yok. Ayarlar > Kategoriler\'den ekleyin.';

  @override
  String get addRecord => 'Kayıt ekle';

  @override
  String get noRecordsThisMonth => 'Bu ay için kayıt yok.';

  @override
  String get newRecord => 'Yeni kayıt';

  @override
  String get editRecord => 'Kaydı düzenle';

  @override
  String get deleteRecordQuestion => 'Kayıt silinsin mi?';

  @override
  String get titleOptional => 'Başlık (isteğe bağlı)';

  @override
  String get categories => 'Kategoriler';

  @override
  String get addCategory => 'Kategori ekle';

  @override
  String get noCategoriesYet => 'Henüz kategori yok.';

  @override
  String get archived => 'Arşivlendi';

  @override
  String get newCategory => 'Yeni kategori';

  @override
  String get editCategory => 'Kategoriyi düzenle';

  @override
  String deleteCategoryQuestion(String name) {
    return '\"$name\" silinsin mi?';
  }

  @override
  String get deleteCategoryWarning =>
      'Bu kategoriye ait TÜM kayıtlar ve tekrarlayan işlemler de silinir. Kayıtları korumak istiyorsanız kategoriyi arşivleyin.';

  @override
  String get name => 'Ad';

  @override
  String get nameRequired => 'Ad gerekli';

  @override
  String get nameTaken => 'Bu adda bir kategori zaten var';

  @override
  String get emojiOptional => 'Emoji (isteğe bağlı, ikon yerine gösterilir)';

  @override
  String get colour => 'Renk';

  @override
  String get icon => 'İkon';

  @override
  String get archive => 'Arşivle';

  @override
  String get archiveHint =>
      'Yeni kayıtlarda gösterilmez, eski kayıtlar korunur.';

  @override
  String get recurringTransactions => 'Tekrarlayan işlemler';

  @override
  String get recurringEmpty =>
      'Kira, maaş, abonelik gibi düzenli işlemleri ekleyin; zamanı gelince otomatik kaydedilsin.';

  @override
  String get finished => 'Bitti';

  @override
  String nextOn(String date) {
    return 'Sonraki: $date';
  }

  @override
  String get newRecurring => 'Yeni tekrarlayan';

  @override
  String get editRecurring => 'Tekrarlayanı düzenle';

  @override
  String get deleteRecurringQuestion => 'Tekrarlayan işlem silinsin mi?';

  @override
  String get deleteRecurringHint =>
      'Daha önce oluşturulmuş kayıtlar silinmez, sadece yenileri oluşmaz.';

  @override
  String get recurringTitleHint => 'Başlık (ör. Kira, Netflix)';

  @override
  String get every => 'Her';

  @override
  String get start => 'Başlangıç';

  @override
  String get endOptional => 'Bitiş (isteğe bağlı)';

  @override
  String get noEnd => 'Süresiz';

  @override
  String get removeEnd => 'Bitişi kaldır';

  @override
  String pastRecordsCreated(int count) {
    return '$count geçmiş kayıt otomatik oluşturuldu';
  }

  @override
  String unitDay(int count) {
    return 'gün';
  }

  @override
  String unitWeek(int count) {
    return 'hafta';
  }

  @override
  String unitMonth(int count) {
    return 'ay';
  }

  @override
  String unitYear(int count) {
    return 'yıl';
  }

  @override
  String get everyDay => 'Her gün';

  @override
  String get everyWeek => 'Her hafta';

  @override
  String get everyMonth => 'Her ay';

  @override
  String get everyYear => 'Her yıl';

  @override
  String everyN(int count, String unit) {
    return 'Her $count $unit';
  }

  @override
  String get periodMonth => 'Ay';

  @override
  String get periodYear => 'Yıl';

  @override
  String get noDataForPeriod => 'Bu dönem için veri yok.';

  @override
  String get total => 'Toplam';

  @override
  String get daily => 'Günlük';

  @override
  String get monthly => 'Aylık';

  @override
  String get settings => 'Ayarlar';

  @override
  String categoryCount(int count) {
    return '$count kategori';
  }

  @override
  String ruleCount(int count) {
    return '$count kural';
  }

  @override
  String get currency => 'Para birimi';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get importOinkoin => 'Oinkoin yedeğini içe aktar';

  @override
  String get importOinkoinHint =>
      'Oinkoin > Ayarlar > Yedekle ile aldığınız .json dosyası';

  @override
  String get pickOinkoinBackup => 'Oinkoin yedeğini seçin';

  @override
  String importDone(
    int records,
    int transfers,
    int categories,
    int wallets,
    int rules,
  ) {
    return 'İçe aktarıldı: $records kayıt, $transfers aktarım, $categories kategori, $wallets cüzdan, $rules tekrarlayan.';
  }

  @override
  String importSkipped(int count) {
    return '$count kayıt zaten vardı.';
  }

  @override
  String get importNotJson => 'Dosya geçerli bir JSON değil.';

  @override
  String get importNotOinkoin => 'Bu dosya bir Oinkoin yedeği gibi görünmüyor.';

  @override
  String get importNotUtf8 => 'Dosya okunamadı (UTF-8 değil).';

  @override
  String importFailed(String error) {
    return 'İçe aktarma başarısız: $error';
  }

  @override
  String get aboutLegalese =>
      'Sade ve gizli bütçe takibi.\nTüm verileriniz cihazınızda kalır.';

  @override
  String get wallet => 'Cüzdan';

  @override
  String get wallets => 'Cüzdanlar';

  @override
  String get allWallets => 'Tüm cüzdanlar';

  @override
  String get addWallet => 'Cüzdan ekle';

  @override
  String get newWallet => 'Yeni cüzdan';

  @override
  String get editWallet => 'Cüzdanı düzenle';

  @override
  String walletCount(int count) {
    return '$count cüzdan';
  }

  @override
  String get startingBalance => 'Başlangıç bakiyesi';

  @override
  String get startingBalanceHint =>
      'Borç için eksi işareti kullanın (ör. kredi kartı)';

  @override
  String get invalidBalance => 'Geçerli bir bakiye girin';

  @override
  String get totalBalance => 'Toplam bakiye';

  @override
  String get walletArchiveHint =>
      'Kayıt eklerken gösterilmez; geçmişi ve bakiyesi korunur.';

  @override
  String deleteWalletQuestion(String name) {
    return '\"$name\" silinsin mi?';
  }

  @override
  String get walletInUse =>
      'Bu cüzdanda kayıt, aktarım veya tekrarlayan işlem var. Bunun yerine arşivleyin.';

  @override
  String get lastWallet => 'En az bir cüzdan olmalı.';

  @override
  String get transfer => 'Aktarım';

  @override
  String get fromWallet => 'Kaynak cüzdan';

  @override
  String get toWallet => 'Hedef cüzdan';

  @override
  String get sameWallet => 'İki farklı cüzdan seçin';

  @override
  String get newTransfer => 'Yeni aktarım';

  @override
  String get editTransfer => 'Aktarımı düzenle';

  @override
  String get deleteTransferQuestion => 'Aktarım silinsin mi?';

  @override
  String get needTwoWallets =>
      'Aktarım yapmak için Ayarlar > Cüzdanlar\'dan ikinci bir cüzdan ekleyin.';

  @override
  String get moneyIn => 'Giriş';

  @override
  String get moneyOut => 'Çıkış';

  @override
  String get net => 'Net';

  @override
  String transferToWallet(String name) {
    return '$name cüzdanına';
  }

  @override
  String transferFromWallet(String name) {
    return '$name cüzdanından';
  }

  @override
  String get pickMonth => 'Ay seçin';

  @override
  String get pickYear => 'Yıl seçin';

  @override
  String get backupCreate => 'Yedekle';

  @override
  String get backupCreateHint =>
      'Tüm verilerini bir dosyaya kaydet (ör. Google Drive\'a)';

  @override
  String get backupRestore => 'Yedekten geri yükle';

  @override
  String get backupRestoreHint => 'Mevcut tüm verilerin yerini alır';

  @override
  String get backupSaved => 'Yedek kaydedildi';

  @override
  String backupFailed(String error) {
    return 'Yedekleme başarısız: $error';
  }

  @override
  String get backupPick => 'Bir YASBA yedeği seçin';

  @override
  String get backupRestoreQuestion => 'Bu yedek geri yüklensin mi?';

  @override
  String backupRestoreDetails(
    String date,
    int wallets,
    int records,
    int transfers,
    int rules,
  ) {
    return '$date tarihli yedek: $wallets cüzdan, $records kayıt, $transfers aktarım, $rules tekrarlayan.\n\nMevcut tüm veriler bununla değiştirilecek. Bu işlem geri alınamaz.';
  }

  @override
  String get backupRestoreConfirm => 'Geri yükle';

  @override
  String get backupRestored => 'Yedek geri yüklendi';

  @override
  String get backupNotBackup => 'Bu dosya bir YASBA yedeği değil.';

  @override
  String get backupNewer =>
      'Bu yedek YASBA\'nın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin.';

  @override
  String get unknownDate => 'bilinmeyen bir';

  @override
  String get autoBackup => 'Otomatik yedek';

  @override
  String get autoBackupOff => 'Kapalı';

  @override
  String get autoBackupDaily => 'Günlük';

  @override
  String get autoBackupWeekly => 'Haftalık';

  @override
  String get autoBackupMonthly => 'Aylık';

  @override
  String get autoBackupOffHint =>
      'Açıkken, uygulamayı açtığında Belgeler/YASBA klasörüne yedek alınır; son 5 yedek tutulur';

  @override
  String autoBackupLast(String date) {
    return 'Son yedek: $date';
  }

  @override
  String get autoBackupNever => 'Henüz otomatik yedek alınmadı';

  @override
  String autoBackupFailed(String error) {
    return 'Son otomatik yedek başarısız: $error';
  }

  @override
  String get exportCsv => 'CSV olarak dışa aktar';

  @override
  String get exportCsvHint =>
      'Tüm kayıtlar, aktarımlar ve borçlar; Excel veya Google Sheets için';

  @override
  String get exportCsvSaved => 'CSV kaydedildi';

  @override
  String get csvDate => 'Tarih';

  @override
  String get csvType => 'Tür';

  @override
  String get csvToWallet => 'Hedef cüzdan';

  @override
  String get csvTitle => 'Başlık';

  @override
  String get csvNote => 'Not';

  @override
  String get tagline => 'Sade ve gizli bütçe takibi';

  @override
  String get debts => 'Borçlar';

  @override
  String get owedToMe => 'Alacaklarım';

  @override
  String get iOwe => 'Borçlarım';

  @override
  String get addDebt => 'Borç ekle';

  @override
  String get newDebt => 'Yeni borç';

  @override
  String get editDebt => 'Borcu düzenle';

  @override
  String get debtLent => 'Borç verdim';

  @override
  String get debtBorrowed => 'Borç aldım';

  @override
  String get person => 'Kişi';

  @override
  String get personRequired => 'Bir isim girin';

  @override
  String get dueDateOptional => 'Son ödeme tarihi (isteğe bağlı)';

  @override
  String get noDueDate => 'Son tarih yok';

  @override
  String get removeDueDate => 'Son tarihi kaldır';

  @override
  String get noWallet => 'Cüzdan yok (bakiyeyi etkilemesin)';

  @override
  String get debtsEmpty =>
      'Verdiğin ya da aldığın borçları ve geri ödemelerini buraya yaz. Borçlar cüzdan bakiyesini değiştirir ama gelir ya da gider sayılmaz.';

  @override
  String get openDebts => 'Açık';

  @override
  String get settledDebts => 'Kapananlar';

  @override
  String get overdue => 'Gecikti';

  @override
  String dueOn(String date) {
    return 'Son: $date';
  }

  @override
  String remainingOf(String remaining, String total) {
    return 'Kalan $remaining / $total';
  }

  @override
  String get debtLentEvent => 'Borç verildi';

  @override
  String get debtBorrowedEvent => 'Borç alındı';

  @override
  String get repaymentReceived => 'Ödeme alındı';

  @override
  String get repaymentMade => 'Ödeme yapıldı';

  @override
  String get addPayment => 'Ödeme ekle';

  @override
  String get payments => 'Ödemeler';

  @override
  String get noPayments => 'Henüz ödeme yok';

  @override
  String get paid => 'Ödenen';

  @override
  String get remaining => 'Kalan';

  @override
  String get closeDebt => 'Kapat';

  @override
  String get reopenDebt => 'Yeniden aç';

  @override
  String get deleteDebtQuestion => 'Borç ve tüm ödemeleri silinsin mi?';

  @override
  String get deletePaymentQuestion => 'Ödeme silinsin mi?';

  @override
  String theyOweMe(String name) {
    return '$name sana borçlu';
  }

  @override
  String iOweThem(String name) {
    return '$name kişisine borçlusun';
  }

  @override
  String get settled => 'Kapandı';

  @override
  String paymentTooBig(String amount) {
    return 'En fazla $amount';
  }

  @override
  String debtSlice(String name) {
    return 'Borç: $name';
  }

  @override
  String get reminders => 'Hatırlatmalar';

  @override
  String get remindersHint => 'O gün bildirim gelir, uygulama kapalıyken bile';

  @override
  String get remindRecurring => 'Tekrarlayan işlemler';

  @override
  String get remindDebts => 'Borç son ödeme tarihleri';

  @override
  String get remindTime => 'Hatırlatma saati';

  @override
  String get notificationsDenied =>
      'YASBA için bildirimler Android ayarlarında kapalı';

  @override
  String reminderRecurring(String name, String amount) {
    return '$name $amount · tekrarlayan';
  }

  @override
  String reminderDebtLent(String name, String amount) {
    return '$name bugün sana $amount ödeyecek';
  }

  @override
  String reminderDebtBorrowed(String name, String amount) {
    return 'Bugün $name kişisine $amount ödeyeceksin';
  }

  @override
  String reminderCount(int count) {
    return 'Bugün için $count hatırlatma';
  }

  @override
  String get forgiveDebt => 'Affet';

  @override
  String get forgiveDebtBorrowed => 'Affedildi';

  @override
  String get forgiveDebtTitle => 'Borcu affet';

  @override
  String get forgiveLentHint =>
      'Gider olarak kaydedilir; cüzdan bakiyesi değişmez.';

  @override
  String get forgiveBorrowedHint =>
      'Gelir olarak kaydedilir; cüzdan bakiyesi değişmez.';

  @override
  String get debtForgiven => 'Borç affı';

  @override
  String get forgivenFigure => 'Affedilen';
}
