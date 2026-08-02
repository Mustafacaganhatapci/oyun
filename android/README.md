# Orbeon — Android

iOS sürümünün (`Lumo/`) Kotlin + Jetpack Compose ile yazılmış tam karşılığı.
Oynanış birebir aynıdır: bölüm üretimi aynı deterministik RNG'yi (SplitMix64)
ve aynı zorluk eğrisini kullandığı için **her bölüm iki platformda da aynı
haritayı üretir**.

## Açmak

Android Studio (Ladybug veya üstü) ile `android/` klasörünü aç. Gradle
senkronizasyonu bağımlılıkları indirir ve wrapper'ı kendisi tamamlar.

Komut satırından derlemek istersen önce wrapper'ı üret:

```bash
cd android
gradle wrapper --gradle-version 8.9
./gradlew assembleDebug
```

## Yayına çıkmadan önce yapılacaklar

1. **Firebase** — Firebase konsolundan Android uygulaması ekle
   (paket adı `com.caganhatapci.orbeon`), `google-services.json` dosyasını
   `android/app/` içine koy ve `app/build.gradle.kts` içindeki
   `com.google.gms.google-services` eklentisinin başındaki `//` işaretini kaldır.
   Dosya eklenmezse sıralama sessizce kapalı kalır, oyun normal çalışır.
   iOS ile **aynı** Firebase projesini kullan: tablo ortak olur.

2. **Play Console ürünleri** — Uygulama içi ürünler şu kimliklerle oluşturulur:

   | Ürün | Kimlik | Tür |
   |---|---|---|
   | Premium | `orbeon.premium` | Tek seferlik |
   | Küçük bahşiş | `orbeon.tip.small` | Tek seferlik (tüketilebilir) |
   | Büyük bahşiş | `orbeon.tip.big` | Tek seferlik (tüketilebilir) |

3. **İmzalama** — `app/build.gradle.kts` içine kendi `signingConfig`'ini ekle;
   Play App Signing kullanıyorsan yalnızca yükleme anahtarı yeterlidir.

4. **Simge** — `res/drawable/ic_launcher_foreground.xml` basit bir yer
   tutucudur. Android Studio → **Image Asset** ile kendi ikonunla değiştir.

5. **Veri güvenliği formu** — Play Console'da beyan edilecekler, iOS'taki
   App Privacy ile aynı: reklam kimliği (izleme: evet), reklam etkileşimi
   (izleme: evet), kullanıcı adı/oyuncu kimliği (izleme: hayır).

## AdMob

**AdMob'da iOS ve Android ayrı uygulamalardır ve kimlikleri farklıdır.** Şu an
release yapılandırması iOS kimliklerini taşıyor; yayına çıkmadan önce AdMob →
Uygulamalar → **Uygulama ekle → Android** ile Orbeon'u kaydet ve şunları
değiştir:

- Uygulama kimliği → `app/build.gradle.kts` içindeki `release` bloğunda
  `manifestPlaceholders["admobAppId"]`
- Geçiş ve ödüllü birimler → `services/AdsManager.kt`

Hata ayıklama derlemelerinde **Google'ın resmi test kimlikleri** kullanılır;
kendi reklamına tıklamak hesabı kapattırabileceği için bu ayrım kasıtlıdır.
Bu sayede emülatörde test reklamları ve UMP formu sorunsuz çalışır.

GDPR onay formu (UMP) reklamlardan **önce** çalışır; onay bitmeden reklam
istenmez. Android'de ATT karşılığı bir istem yoktur — reklam kimliği sistem
ayarlarından yönetilir.

## Yapı

```
model/     Level.kt      Bölüm üretimi, zorluk eğrisi, SplitMix64
           OrbStyle.kt   Küre stilleri ve açılma koşulları
theme/     Theme.kt      10 tema paleti
game/      GameEngine.kt Simülasyon — çizimden bağımsız, saf mantık
store/     Stores.kt     İlerleme, ayarlar, oyuncu, günlük ödül, görevler
services/  BillingManager, AdsManager, ConsentManager,
           LeaderboardService, AudioEngine, Haptics, ReviewPrompt
ui/        RootScreen (navigasyon), GameScreen (tuval + HUD),
           Screens.kt (menü, bölümler, mağaza, ayarlar, ad, sıralama)
```

`GameEngine` hiçbir Compose/Android çizim türüne bağlı değildir; yalnızca
durum tutar. Çizim `GameScreen.kt` içindeki `GameCanvas`'tadır. Bu ayrım
sayesinde oynanış render'dan bağımsız kalır ve test edilebilir.
