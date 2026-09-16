# Yayın kontrol listesi — 2.3 (build 10)

Sıra önemli: yukarıdakiler yayını **engelliyor**, aşağıdakiler engellemiyor.
Bugün göndermek istiyorsan 0–4 arası yeter; 5 ve sonrası bu akşam ya da
yarın yapılabilir.

Projenin sayıları (adımlarda lazım olacak):

| | |
|---|---|
| Bundle ID | `com.caganhatapci.lumo` |
| Team ID | `TDJ59SWRZJ` |
| Sürüm / build | **2.3 / 10** (repoda ayarlı, dokunma) |
| Firebase projesi | `lumo-890fb` |

---

## 0. ÖNCE DERLE — en büyük bilinmeyen bu

Bu oturumda bölüm kuralları epeyce değişti ve **hiçbiri Xcode'da
derlenmedi**. Swift dosyalarının tamamı sözdizimi taramasından geçti, ama
tip kontrolü (UIKit/SpriteKit) yalnızca Xcode'da yapılabiliyor.

1. Xcode'da `Lumo.xcodeproj`'u aç
2. Paketler çözülsün diye bir dakika bekle ("Resolving Package Graph")
3. **⌘B** (Build)

Hata çıkarsa bana yapıştır — çoğu tek satırlıktır.

Derleme geçtiyse **gerçek cihazda ⌘R** ve şunları bir kez gör:

- [ ] Öğreticiyi baştan oyna (Ayarlar → Nasıl oynanır). **Dört altyazının
      dördü de** çıkmalı; üçüncüsünde kapı sönük durmalı, yıldızı alınca
      yanmalı.
- [ ] **39. bölüm** — kırmızı tuzak kapı. Önce bir iki yıldız topla, sonra
      bilerek üstüne git: bölüm **baştan** kurulmalı ve **yıldız sayacı
      sıfırlanmalı** (kapı da yeniden sönmeli). Kart bir kez çıkmalı.
- [ ] **Süreli bir bölüm (Android)** — süreyi bilerek doldur: bölüm baştan
      kurulmalı, yıldızlar geri gitmeli. Bu Android'de hiç yoktu.
- [ ] **26. bölüm** — basılı tut, zaman yavaşlamalı; kürenin çevresinde
      dolum yayı görünmeli.
- [ ] Herhangi bir bölüm: yıldız almadan kapıya git — açılmamalı.

> Bunlar benim buradan göremediğim şeyler. Tuzak kapının yeri adil mi,
> yavaşlatma iyi hissettiriyor mu — ancak elde belli olur.

---

## 1. Crashlytics (10 dakika) — ARŞİVDEN ÖNCE

Neden şimdi: bu sürüm oyunun kurallarını değiştiriyor. Bir yerde çökerse
Crashlytics olmadan **haberin olmaz**. Kod zaten yazılı (`Diagnostics.swift`),
yalnızca paket bağlı değil.

**a. Ürünü hedefe ekle**

Xcode → sol panelde proje adına tıkla → **TARGETS → Lumo** → **General**
sekmesi → aşağıda **Frameworks, Libraries, and Embedded Content** → **+**

Açılan listede **FirebaseCrashlytics**'i bul (firebase-ios-sdk zaten ekli,
yeni paket eklemiyorsun) → **Add**.

**b. Run Script derleme aşaması ekle**

Aynı ekranda **Build Phases** sekmesi → sol üstte **+** → **New Run Script
Phase**. Adı önemli değil. İçine tek satır:

```sh
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

Altındaki **Input Files** bölümüne **+** ile iki satır:

```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

> Bu aşama, çökme yığın izlerini okunabilir hâle getiren dSYM dosyasını
> Firebase'e yüklüyor. Olmazsa çökmeler yine toplanır ama "0x1043f2a8"
> gibi anlamsız satırlar olarak gelir.

> Yol bulunamazsa: Xcode → File → Packages → **Resolve Package Versions**
> çalıştır, sonra tekrar dene.

**c. Doğrula**

Derle, uygulamayı bir kez aç ve kapat. Firebase konsolu → **Crashlytics** →
birkaç dakika içinde "uygulamanız algılandı" ekranı geçmeli.

---

## 2. Arşivle ve yükle

1. Xcode üstte cihaz seçiciden **Any iOS Device (arm64)** seç
   (gerçek cihaz ya da simülatör seçiliyken Archive kapalı kalır)
2. **Product → Archive**
3. Biten arşivde **Distribute App → App Store Connect → Upload**
4. İmzalama sorularında varsayılanları geç, **Upload**

Yükleme bitince App Store Connect'te işlenmesi 10–30 dakika sürüyor.
Bu sırada 3. adımı yap.

> **"Invalid Swift Support" ya da dSYM uyarıları** gelirse yükleme yine
> tamamlanır; o uyarılar yayını engellemiyor.

---

## 3. App Store Connect — metinler ve gizlilik

**a. Yeni sürüm oluştur**

App Store Connect → Orbeon → sol üstte **+ Version or Platform** → `2.3`

**b. Yenilikler**

`ios-store-assets/appstore-2.3.md` dosyasındaki metinleri yapıştır:
TR, EN, ES için ayrı ayrı (dil seçici sayfanın üstünde).

> **Kırmızı kapı en başta yazıyor, bilerek.** Eski oyuncu beyaz kapıyı
> "kısa yol" diye öğrendi, aynı yerde artık ölüyor. Bu cümleyi aşağı
> çekme — oyuncu onu ölerek öğrenmesin.

**c. Ekran görüntüleri**

2.2'dekiler geçerli, dokunma. Bu sürümde arayüz değişmedi.

**d. App Privacy — BU ADIM YAYINI ENGELLİYOR**

App Store Connect → Orbeon → sol menü **App Privacy** → **Edit**

Beyan edilecekler:

| Kategori | Tür | Kimliğe bağlı | İzleme |
|---|---|---|---|
| Identifiers | User ID | **Evet** | Hayır |
| Diagnostics | Crash Data | **Evet** | Hayır |
| Diagnostics | Other Diagnostic Data | **Evet** | Hayır |
| User Content | Other User Content | **Evet** | Hayır |
| Purchases | Purchase History | **Evet** | Hayır |
| Identifiers | Device ID | Hayır | **EVET** |
| Usage Data | Product Interaction | Hayır | **EVET** |

İlk beşinin amacı **App Functionality**. Son ikisi AdMob'un topladığı ve
amacı **Third-Party Advertising** — izleme kutusu onlarda işaretli.

> İlk beşi `Lumo/PrivacyInfo.xcprivacy` dosyasında da yazılı; manifesto ile
> formun aynı şeyi söylemesi gerekiyor.

**e. Gönder**

Build işlenince sürüme ekle → **Add for Review** → **Submit**.

---

## 4. Play Console (Android)

`versionCode 9 / versionName 2.3` repoda ayarlı.

1. Android Studio → **Build → Generate Signed Bundle / APK → Android App Bundle**
2. Play Console → Production → **Create new release** → AAB'yi yükle
3. Sürüm notlarına `ios-store-assets/appstore-2.3.md` içindeki
   **Play (500 karakter)** bölümünü yapıştır
4. **Veri güvenliği formunu güncelle** — `android/store-listing.md` içindeki
   tabloya göre. 2.2'de "kilitlenme/analiz SDK'sı eklenmedi" yazıyordu,
   artık yanlış: Crashlytics ve görüş kutusu eklendi.

---

## 5. Yayını engellemeyenler — sonra

**a. Firestore kuralları** (2 dakika)

Firebase konsolu → Firestore Database → **Rules** → `firestore.rules`
dosyasının içeriğini yapıştır → **Publish**.

Yayınlanmazsa ilerleme sayacı (`stats/progress_ios`) yazamaz. Oyun
etkilenmez, sessizce atlar — ama "insanlar nerede bırakıyor" verisi hiç
birikmez.

**b. Duyuru belgesindeki `appStoreID`** (1 dakika)

Firestore → `config` → `announcement` → `appStoreID` alanı hâlâ benim
açıklama metnimi taşıyor. **10 haneli sayıyla** değiştir.

Bulacağın yer: App Store Connect → Orbeon → **App Information** →
**General Information** → **Apple ID**.

Düzeltmezsen "Güncelle" düğmesi görünür ama basınca hiçbir şey olmaz.

> Duyuruyu (`enabled: true`) **ancak 2.3 gerçekten yayına girince** aç.
> `minVersion` alanını da `2.3` yap, yoksa güncellemeyi almış olana da
> "güncelle" dersin.

**c. RevenueCat** (5 dakika)

Xcode → **File → Add Package Dependencies…** → arama kutusuna:

```
https://github.com/RevenueCat/purchases-ios
```

→ **Add Package** → ürün listesinden **RevenueCat** → hedef `Lumo` → Add.

API anahtarı kodda zaten yazılı (`RevenueCatBridge.swift`). Paket eklenince
gözlemci kipinde kendiliğinden çalışmaya başlıyor: satın almayı StoreKit
yürütüyor, RevenueCat yalnızca kaydediyor.

**d. NSPrivacyTracking**

`Lumo/PrivacyInfo.xcprivacy` içinde şu an `false` ve alan adı listesi boş.
Kişiselleştirilmiş reklam açıkken `true` olması ve
`NSPrivacyTrackingDomains`'e AdMob'un alan adlarının yazılması gerekiyor.

**Listeyi Google'ın kendi dokümanından birebir al.** Ezberden yazılan bir
alan adı, boş bırakmaktan kötüdür.

**e. APNs `.p8`** — yalnızca "herkese tek seferlik duyuru" için gerekiyor.
Ana menüdeki duyuru kartı ve yerel hatırlatmalar bunu beklemiyor.
Adımları `BILDIRIM.md` §3'te.

---

## Sırayla, kısa hâli

```
0. ⌘B → gerçek cihazda dene (öğretici, 39, 26)
1. Crashlytics: ürün + run script
2. Any iOS Device → Archive → Upload
3. ASC: 2.3 sürümü, yenilikler, App Privacy → Submit
4. Play: AAB → sürüm notu → veri güvenliği formu
─── buradan sonrası yayını engellemiyor ───
5. Firestore rules · appStoreID · RevenueCat · tracking domains · .p8
```
