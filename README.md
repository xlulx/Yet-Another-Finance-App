# YAFA — Yet Another Financial App

Gizlilik odaklı, tamamen çevrimdışı çalışan gelir/gider takip uygulaması.
Flutter ile yazıldı (Android + iOS). Tüm veriler cihazdaki SQLite
veritabanında tutulur; hiçbir yere gönderilmez.

## Özellikler (v0.1)

- **Gelir / gider kayıtları** — ay ay listeleme, günlere göre gruplama,
  kaydırarak silme (geri alma ile), aylık gelir/gider/bakiye özeti.
- **Kategoriler** — ad, renk, ikon veya emoji; arşivleme.
- **İstatistik** — aylık/yıllık kategori dağılımı (pasta grafik + yüzdeler)
  ve günlük/aylık trend grafiği.
- **Tekrarlayan işlemler** — "her N gün/hafta/ay/yıl"; vadesi gelen kayıtlar
  uygulama açılınca otomatik oluşturulur. Ay sonu tarihleri doğru işlenir
  (31 Ocak → 28 Şubat → 31 Mart).
- **Oinkoin'den geçiş** — Oinkoin'in `.json` yedeğini içe aktarır: kategoriler
  (renk, emoji), kayıtlar ve tekrarlayan işlemler (özel aralıklar dahil).
  Aynı yedeği iki kez içe aktarmak kayıtları çoğaltmaz.

## Geliştirme

```bash
flutter pub get
flutter analyze
flutter test
flutter run --flavor dev   # bağlı cihaz/emülatörde çalıştır
```

### Sürümler (flavor)

| Flavor | Uygulama adı | Paket | Nerede derlenir |
|---|---|---|---|
| `dev`  | YAFA Dev | `io.github.xlulx.yafa.dev` | Geliştirme ortamında, test için |
| `prod` | YAFA     | `io.github.xlulx.yafa`     | Sadece GitHub Release ile |

İkisi telefonda yan yana kurulabilir; verileri ayrıdır. Test sürümü
herkese açık `android/keystores/dev.jks` ile imzalanır.

```bash
flutter build apk --release --flavor dev --target-platform android-arm64
```

### Release (Actions dakikası sadece burada harcanır)

`v0.1.0` gibi bir etiket gönderilince (`git tag v0.1.0 && git push origin v0.1.0`
ya da GitHub'da **Releases → Draft a new release**) `.github/workflows/release.yml`
çalışır, testleri koşar, Release'i oluşturur ve imzalı `YAFA-0.1.0.apk`
dosyasını ekler (~6-8 dk). Bunun için
`RELEASE_KEYSTORE_BASE64` ve `RELEASE_KEYSTORE_PASSWORD` secret'ları gerekir.
İmza anahtarı depoda **yoktur**.

## Mimari

```
lib/
  models/      Category, Record, RecurringRule (saf veri sınıfları)
  data/        AppDatabase — sqflite şeması ve sorgular
  services/    recurrence (tarih hesabı), recurring_service, oinkoin_import, stats
  state/       AppState (ChangeNotifier, provider ile)
  ui/          sayfalar ve ortak widget'lar
  utils/       para biçimlendirme/ayrıştırma, ikon ve renk listeleri
```

- Tutarlar **kuruş cinsinden tam sayı** olarak saklanır (yuvarlama hatası yok).
  Tutar her zaman pozitiftir; yönü kategorinin türü (gelir/gider) belirler.
- Enum index'leri veritabanında saklanır: yeni değerleri **sadece sona** ekleyin.

## Yol haritası (fikirler)

- Kendi yedek/geri yükleme (JSON) ve CSV dışa aktarma
- Bütçeler ve limit uyarıları
- Çoklu cüzdan / hesaplar arası transfer
- Etiketler ve arama
- Ana ekran widget'ı, uygulama kilidi (biyometrik)
- İngilizce dil desteği
