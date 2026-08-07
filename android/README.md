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

Derleme durumu: `assembleDebug` ve R8 küçültmesi açık `bundleRelease`
(AGP 8.6 / Gradle 8.14 / JDK 21, compileSdk 35) temiz bir ortamda
hatasız tamamlanıyor.

## Yayına çıkmadan önce yapılacaklar

1. ~~**Firebase**~~ — bağlandı. `app/google-services.json` iOS ile **aynı**
   projeyi (`lumo-890fb`) gösterir, dolayısıyla dünya sıralaması iki platformda
   ortaktır. Firestore kuralları ve koleksiyon adları da ortak.

2. **Play Console ürünleri** — Uygulama içi ürünler şu kimliklerle oluşturulur:

   | Ürün | Kimlik | Tür |
   |---|---|---|
   | Premium | `orbeon.premium` | Tek seferlik |
   | Küçük bahşiş | `orbeon.tip.small` | Tek seferlik (tüketilebilir) |
   | Büyük bahşiş | `orbeon.tip.big` | Tek seferlik (tüketilebilir) |

3. **İmzalama** — bağlantısı kuruldu, geriye anahtarı üretmek kaldı.
   `app/build.gradle.kts` release'i `android/keystore.properties` dosyasını
   okur; dosya yoksa release yine derlenir ama **imzasız** çıkar ve Play
   kabul etmez. Anahtar kendi makinende üretilmeli — bu depoya asla girmez
   (`.gitignore`'da).

   ```bash
   cd android
   keytool -genkeypair -v \
     -keystore upload-keystore.jks \
     -alias orbeon-upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

   Sonra `android/keystore.properties` dosyasını oluştur:

   ```properties
   storeFile=upload-keystore.jks
   storePassword=<keytool'a verdiğin parola>
   keyAlias=orbeon-upload
   keyPassword=<aynı parola>
   ```

   > `upload-keystore.jks` ve parolayı yedekle. Play App Signing açıksa
   > kaybedersen Google'dan yükleme anahtarı sıfırlaması isteyebilirsin,
   > ama bu birkaç gün sürer.

   Play'e yüklenecek paketi üret:

   ```bash
   ./gradlew bundleRelease
   # çıktı: app/build/outputs/bundle/release/app-release.aab
   ```

4. **Mağaza metinleri** — Play Console'a girilecek ad, açıklamalar, ürün
   kimlikleri, veri güvenliği ve içerik derecelendirmesi cevapları
   `store-listing.md` içinde hazır duruyor.

5. **Veri güvenliği formu** — Play Console'da beyan edilecekler, iOS'taki
   App Privacy ile aynı: reklam kimliği (izleme: evet), reklam etkileşimi
   (izleme: evet), kullanıcı adı/oyuncu kimliği (izleme: hayır).

## AdMob

**AdMob'da iOS ve Android ayrı uygulamalardır ve kimlikleri farklıdır.**
Android tarafı kayıtlı ve bağlı:

| Ne | Kimlik | Nerede |
|---|---|---|
| Uygulama | `...~9317548394` | `app/build.gradle.kts` → `release` |
| Geçiş reklamı | `.../2256783191` | `services/AdsManager.kt` |
| Ödüllü reklam | `.../5880901650` | `services/AdsManager.kt` |

Bir birim boş bırakılırsa istek yapılmaz; oyun reklamsız çalışmaya devam
eder ve ödüllü düğme "şu an reklam yok" der.

Hata ayıklama derlemelerinde **Google'ın resmi test kimlikleri** kullanılır;
kendi reklamına tıklamak hesabı kapattırabileceği için bu ayrım kasıtlıdır.
Bu sayede emülatörde test reklamları ve UMP formu sorunsuz çalışır.

GDPR onay formu (UMP) reklamlardan **önce** çalışır; onay bitmeden reklam
istenmez. Android'de ATT karşılığı bir istem yoktur — reklam kimliği sistem
ayarlarından yönetilir.

## Bölüm türleri

150 bölüm var; 1...120 ilk sürümdekiyle **birebir aynı** üretilir. Zorluk
eğrisinin paydası `LEGACY_COUNT`'a sabitlendiği için bölüm sayısını
artırmak eski bölümlerin düzenini kaydırmaz — kayıtlı ilerleme geçerli kalır.

| Tür | Nerede | Kural |
|---|---|---|
| Normal | her yerde | Kapıya ulaş, yol üstündeki 3 lümeni topla |
| Bonus | her 6. bölüm | Tehlike ve kapı yok; süre dolana kadar lümen topla |
| Süreli | 12. normal bölümden itibaren her 4'te bir | Kapıya süre dolmadan ulaş |
| Topla-bitir | 121'den itibaren, `id % 3 == 1` | Kapı tüm lümenler toplanmadan açılmaz; ölünce bölüm sıfırdan, lümenler geri gelir |
| Büyük yıldız | 121'den itibaren, `id % 3 == 2` | 3 küçük lümen yerine 4 eden tek bir iri yıldız |

Oyalanma süresi (`dwellLimit`) dolduğunda küre **ölmez, kendiliğinden
fırlar**. Yayın son üçte biri kırmızıya döner: bu, otomatik fırlatmanın
geldiğini haber veren uyarıdır, ceza değil.

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
