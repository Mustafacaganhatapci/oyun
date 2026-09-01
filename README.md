# LUMO — Işığın Yolculuğu 🪐

Tek parmakla oynanan, App Store'a hazır, SwiftUI + SpriteKit tabanlı bir iOS oyunu.
Bir ışık küresini halkadan halkaya sıçratarak yolun sonundaki kapıya ulaştırırsın.
**Tek kural, tek dokunuş:** küre halkada dönerken ekrana dokun — küre teğet doğrultuda fırlar.

---

## 🎮 Oynanış

| Mekanik | Açıklama |
|---|---|
| **Tek dokunuş** | Küre halkanın yörüngesinde döner; dokununca teğet yönde fırlar. Zamanlama her şeydir. |
| **Yakalama** | Küre başka bir halkanın içine girerse o yörüngeye oturur ve geliş yönüne göre dönmeye başlar. |
| **Lumen** | Her bölümde 3 altın ışık parçası vardır; uçuş hattı üzerindedir. Toplananlar bölüm sonunda yıldıza dönüşür. |
| **Tehlike yayları** | Kırmızı yaylara değersen düşersin. İleri bölümlerde yaylar döner. |
| **Hareketli halkalar** | 11. bölümden itibaren halkalar salınır — zamanlama derinleşir. |
| **Kapı halkası** | Kesikli turkuaz halka. Ona oturduğun an bölüm biter. |
| **Kombo müziği** | Düşmeden yaptığın her sıçrama, pentatonik dizide bir üst notayı çalar — iyi oynadıkça melodi yükselir. |

- **48 bölüm** (40 normal + 8 bonus; deterministik üreteç — her cihazda birebir aynı)
- **Bonus turları**: her 6. bölüm süreli lumen avıdır — 25 saniyede 9 lumen, tehlike yok
- **Sonsuz Mod**: 10. bölümü bitirince açılır; yükseldikçe zorlaşır, rekor tutulur
- **Speed Run**: ilk 10 bölüm kronometreye karşı; her ölüm +2 sn ceza, en iyi süre kaydedilir
- **Dünya sıralaması**: Game Center liderlik tabloları (sonsuz mod skoru + speed run süresi)
- **Yılan haritası**: bölümler kıvrılan bir patika üzerinde ilerler, mevcut bölüm nefes alır
- Düşünce anında yeniden doğarsın — bekleme ekranı yok, "bir kere daha" döngüsü kesintisiz
  (yeniden doğma update döngüsüne bağlıdır; takılı kalırsa tek dokunuş anında canlandırır)

## 🎨 Tasarım Kimliği

- **6 tema** (2 ücretsiz + 4 premium): Nebula, Gece, Şafak, Orman, Mercan, Aurora.
  Her tema; arka plan degradesi, halka, kapı, küre, tehlike, lumen ve vurgu renklerini
  tek yerden tanımlar (`Theme/Theme.swift`). Renk kimliği eksiksizdir.
- **6 küre stili** (2 ücretsiz + 4 premium): Işık, Yıldız, Kristal, Kuyruklu Yıldız,
  Gökkuşağı ve **Fotoğraf** — premium'da oyuncu kürenin içine kendi fotoğrafını koyar
  (fotoğraf cihazda kalır, hiçbir yere yüklenmez). Tamamı kozmetiktir.
- Neon-glow estetiği: additive blend parçacıklar, ışık izleri, nefes alan halkalar,
  süzülen yıldız tozu.
- Tipografi: SF Rounded (sistem) — yumuşak, oyuncu, ek font dosyası gerekmez.
- Portre + tek el: tüm oyun alanı dokunmatiktir, menü eylemleri başparmak bölgesindedir.

## 🌍 6 Dil Desteği

Tüm arayüz **String Catalog** (`Lumo/Localizable.xcstrings`) ile yerelleştirilmiştir:

| Dil | Kod | | Dil | Kod |
|---|---|---|---|---|
| 🇬🇧 İngilizce (kaynak) | `en` | | 🇫🇷 Fransızca | `fr` |
| 🇹🇷 Türkçe | `tr` | | 🇪🇸 İspanyolca | `es` |
| 🇩🇪 Almanca | `de` | | 🇯🇵 Japonca | `ja` |

- Tema adları dahil tüm metinler çevrilidir; `LUMO`, fiyatlar ve emoji gibi
  anahtarlar `shouldTranslate: false` ile işaretlidir.
- IAP ürün adları/açıklamaları da `Lumo.storekit` içinde 6 dilde tanımlıdır
  (App Store Connect'te aynı metinleri kullanabilirsin).
- Yeni dil eklemek için: Xcode'da `Localizable.xcstrings` > + > dili seç, çevirileri doldur.
- Simülatörde test: Scheme > Options > App Language.

## 🎵 Ses Tasarımı — %100 Prosedürel

Hiç ses dosyası yoktur; her şey `AVAudioEngine` ile cihazda sentezlenir:

- **Müzik**: Am–F–C–G akor yürüyüşünde, portamentolu, LFO'lu ambient pad.
- **Efektler**: pentatonik pluck (sıçrama, kombo ile perde yükselir), kıvılcım (lumen),
  yumuşak düşüş tonu, kazanma arpeji.
- Ses oturumu `.ambient` + `mixWithOthers`: oyuncu kendi müziğini dinliyorsa pad susar,
  sessize alma anahtarına saygı duyulur.
- **CoreHaptics**: sıçrama, toplama, düşme ve kazanma için ayrı dokunsal desenler.

## 💰 Gelir Modeli — Pay-to-Win YOK

| Kural | Uygulama |
|---|---|
| İlk **10 bölüm tamamen reklamsız** | `AdsManager` seviye ≤ 10 iken asla reklam çağırmaz |
| 11. bölümden sonra | Her 2 bölüm tamamlamada 1 geçiş reklamı; sonsuz modda her 3 oyunda 1 |
| Banner yok | Oyun alanı her zaman temiz |
| **Premium (tek seferlik)** | Reklamları kalıcı kaldırır + 4 tema + 4 küre stili (fotoğraflı küre dahil) — *sadece kozmetik* |
| Bahşiş kavanozu | ☕️ 0.99 / 🌟 4.99 — tamamen gönüllü destek |
| Şeffaflık | Mağaza ekranında açıkça yazar: "Hiçbir satın alma oyun avantajı vermez." |

Satın almalar **StoreKit 2** iledir (`StoreManager.swift`); `Lumo.storekit` dosyasıyla
Xcode'da sandbox'sız test edilebilir (Scheme > Options > StoreKit Configuration).

## 📁 Proje Yapısı

```
Lumo.xcodeproj/          Xcode 16 projesi (dosya-sistemi eşitlemeli, ayarsız açılır)
Lumo/
├── LumoApp.swift        Giriş, ortam nesneleri, rota
├── Theme/Theme.swift    6 temanın tam renk tanımı
├── Models/Level.swift   Bölüm modeli + deterministik 30 bölümlük kütüphane + zorluk eğrisi
├── Game/GameScene.swift SpriteKit sahnesi: yörünge fiziği, yakalama, tehlike, sonsuz mod
├── Services/
│   ├── AudioEngine.swift    Prosedürel müzik + sentez SFX
│   ├── Haptics.swift        CoreHaptics desenleri (UIKit yedekli)
│   ├── ProgressStore.swift  Yıldızlar, kilitler, rekorlar (UserDefaults)
│   ├── SettingsStore.swift  Müzik/SFX/titreşim/tema tercihleri
│   ├── StoreManager.swift   StoreKit 2: premium + bahşişler
│   └── AdsManager.swift     Reklam politikası + AdMob sağlayıcısı (canImport ile)
├── Views/               Menü, bölüm seçimi, oyun HUD'u, mağaza, ayarlar
├── Assets.xcassets      Uygulama ikonu (üretilmiş 1024px) + AccentColor
├── PrivacyInfo.xcprivacy Gizlilik manifestosu (takip yok, veri toplama yok)
└── Lumo.storekit        Yerel IAP test yapılandırması
```

## 🚀 Çalıştırma

1. `Lumo.xcodeproj`'u **Xcode 16+** ile aç.
2. Signing & Capabilities'te kendi Team'ini seç (bundle id: `com.caganhatapci.lumo`).
3. iPhone simülatöründe veya cihazda çalıştır. Ek bağımlılık yoktur — proje olduğu gibi derlenir.
4. IAP testi için: Scheme > Edit Scheme > Options > StoreKit Configuration > `Lumo.storekit`.

### Dünya Sıralaması (Firebase)

Dünya sıralaması Firebase Firestore ile çalışır. Kod hazır ve `canImport` ile
korumalı — SDK yokken uygulama yerel modda çalışır (yerel en iyi skoru gösterir).
Etkinleştirmek için:

1. [Firebase konsolu](https://console.firebase.google.com)'nda yeni proje oluştur,
   iOS uygulaması ekle (bundle id: `com.caganhatapci.lumo`).
2. `GoogleService-Info.plist` dosyasını indir, Xcode'da `Lumo` klasörüne sürükle
   ("Copy items if needed" işaretli).
3. Xcode > File > Add Package Dependencies… →
   `https://github.com/firebase/firebase-ios-sdk` → **FirebaseFirestore** ve
   **FirebaseAuth** ürünlerini `Lumo` hedefine ekle.
4. Firebase konsolu > Firestore Database > oluştur. Kurallar (basit, herkese açık okuma):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /{col}/{doc} {
         allow read: if true;
         allow write: if request.auth != null;
       }
     }
   }
   ```
5. Firebase konsolu > Authentication > Sign-in method > **Anonymous**'ı aç.

Kod `GoogleService-Info.plist` yoksa Firebase'i hiç başlatmaz (çökme olmaz).
Oyuncular ilk kez sıralamaya girerken bir **kullanıcı adı** belirler (3–16 karakter);
skorlar bu adla `leaderboard_endless` ve `leaderboard_speedrun` koleksiyonlarına yazılır.

### Gerçek reklamları (AdMob) açmak

Kod SDK'sız da tam çalışır (DEBUG'da yer tutucu reklam, RELEASE'te reklamsız akış).
Şu an **Google'ın resmi test reklamları** ayarlı: test geçiş reklamı birimi
(`ca-app-pub-3940256099942544/4411468910`) ve test uygulama kimliği Info'da hazır.
SDK'yı ekleyince gerçek test reklamları görünür. Yayın öncesi kendi kimliklerinle değiştir:

1. File > Add Package Dependencies… → `https://github.com/googleads/swift-package-manager-google-mobile-ads` (11.x)
2. Info ayarlarına `GADApplicationIdentifier` (AdMob uygulama kimliğin) ekle.
3. `AdsManager.swift` içindeki test reklam birimini kendi geçiş reklamı kimliğinle değiştir.
4. `AdMobProvider` `canImport(GoogleMobileAds)` sayesinde otomatik devreye girer.
5. PrivacyInfo.xcprivacy'yi AdMob'un istediği alanlarla güncelle (SDK dokümanındaki hazır blok).

## ✅ App Store Kontrol Listesi

- [x] Portre, tek el, tam ekran; durum çubuğu gizli
- [x] Gizlilik manifestosu (takip yok, veri toplanmıyor)
- [x] 1024px uygulama ikonu
- [x] StoreKit 2 + Geri Yükleme düğmesi (App Review şartı)
- [x] Reklamsız ilk deneyim (ilk 10 bölüm) — inceleme sırasında reklam sorunu yaşanmaz
- [ ] App Store Connect'te 3 IAP ürününü oluştur (`lumo.premium`, `lumo.tip.small`, `lumo.tip.big`)
- [ ] Game Center'ı etkinleştir + 2 liderlik tablosu (`lumo.endless`, `lumo.speedrun`)
- [ ] Ekran görüntüleri (6.9" ve 6.5") + tanıtım metni
- [ ] AdMob kimliklerini gerçek değerlerle değiştir
- [ ] Gizlilik politikası URL'i (reklam SDK'sı eklenince gerekli)

## 📊 Sıralama doldurmaları

Pazartesi sabahı haftalık tablo bomboş açılıyor ve boş bir sıralamaya kimse
oynamıyor. `LeaderboardSeed` ilk 50'de boş kalan yerlere Türkçe ve yabancı
adlarla doldurma kayıtları ekliyor.

**Nasıl çalışıyor:** her doldurmanın adı, skoru ve GÖRÜNME ANI hafta
numarasından türetiliyor — hepsi aynı anda belirmiyor, hafta boyunca sızıyor.
Belge kimliği `bot_w<hafta>_<sıra>` olduğu için iki cihaz aynı anda yazsa bile
tabloda tek satır oluyor. Konsolda `seed: true` alanından tanınırlar.

**Gerçek oyunculara dokunulmuyor:**
- Şampiyonluk ödülü sıralaması doldurmaları saymaz; kimse sahte bir adın
  arkasında kalıp yıldızını kaybetmez.
- Gerçek oyuncular çoğaldıkça doldurmalar listeden düşer, gerçek olan hep kalır.

**Ayarlar** Firestore'da `config/leaderboard` belgesinden. Belge yoksa koddaki
varsayılanlar çalışır.

| Alan | Tür | Varsayılan | Ne yapar |
|---|---|---|---|
| `botsEnabled` | boolean | `true` | `false` yaparsan yeni doldurma yazılmaz |
| `botTarget` | int64 | `50` | İlk kaç sıra dolu tutulsun (en çok 50) |
| `botEndlessBest` | int64 | `33` | En iyi doldurmanın skoru |
| `botEndlessWorst` | int64 | `6` | En kötüsü |
| `botSpeedrunBest` | double | `52` | Hız turunda en iyi süre (saniye) |
| `botSpeedrunWorst` | double | `145` | En kötü süre |

Skorlar iki uç arasında karesel dağılıyor: yüksek skorlar seyrek, çoğunluk
alt bantta — gerçek bir tabloya benzesin diye.

Yazılmış doldurmaları silmek istersen o haftanın koleksiyonundan `bot_` ile
başlayan belgeleri sil; `botsEnabled` false ise geri gelmezler.

## 🎟️ Premium kodu verme

Kodlar iki yerden okunuyor: `StoreManager.promoCodes` (koda gömülü, çevrimdışı
da çalışır) ve Firestore'daki **`promoCodes`** koleksiyonu. İkincisi konsoldan
anında yönetilir, yeni sürüm göndermeye gerek yok.

Yeni kod vermek için Firebase Console → Firestore Database → `promoCodes`
koleksiyonunda **belge kimliği kodun küçük harfli hâli** olacak şekilde belge
aç (örn. `kanka2026`) ve şu alanları koy:

| Alan | Tür | Ne işe yarar |
|---|---|---|
| `active` | boolean | `false` yaparsan kod anında kapanır |
| `maxUses` | number | Kaç kişi kullanabilir. `0` ya da hiç yazmazsan sınırsız |
| `uses` | number | `0` ile başlat, uygulama kendisi artırır |
| `note` | string | Kimin için verildiği — yalnızca senin göreceğin not |

Uygulama kodu bir işlem (transaction) içinde okuyup sayacı artırıyor, yani iki
kişi aynı anda son hakkı kullanamıyor. Aynı oyuncu kodu tekrar girerse hak
düşmüyor (telefon değiştirene kolaylık).

Güvenlik kuralları `promoCodes` için `get`'e izin verip `list`'i kapatıyor:
kimliğini bildiğin tek bir kodu sorabilirsin, koleksiyonun tamamını çekemezsin.
`firestore.rules` dosyasını yayınlamayı unutma.

## 💛 Destekçiler

Her satın alma Firestore'daki **`supporters`** koleksiyonuna yazılır. Amaç
muhasebe değil: kimin desteklediğini bilip sonradan hediye premium ya da kod
gönderebilmek.

Belge kimliği `playerID`, alanlar: `username`, `products` (aldığı ürünler),
`purchaseCount`, `lastPrice`, `lastPurchaseAt`.

Güvenlik kuralları bu koleksiyonda **okumayı istemciye kapatır** — oyuncu adı
ve satın alma geçmişi yalnızca Firebase konsolundan görünür.

Bahşiş bırakan da premium alır (`recomputePremium` içinde `isSupporter` de
sayılıyor): parasını oyunu desteklemek için veren birine "bu ayrıca satılıyor"
demek nezaketsizlik olurdu.

> **Not:** Bu koleksiyon satın alma kaydını kullanıcı adıyla ilişkilendiriyor.
> App Store gizlilik etiketinde **Purchases → Linked to You**, Play Data Safety
> tarafında da satın alma geçmişi beyanı gerekir. Beyan etmezsen inceleme
> reddedilebilir.

## 📄 app-ads.txt (AdMob uygulama doğrulaması)

`app-ads.txt` depo kökünde duruyor. AdMob'un "Uygulamayı doğrula" adımı için
**yayın alan adının kökünden** sunulması gerekir — alt klasör kabul edilmez:

```
https://<alan-adin>/app-ads.txt      ✅
https://<alan-adin>/privacy/app-ads.txt   ❌
```

Doğrulamanın geçmesi için iki şey birden gerekir:

1. Bu dosya alan adının kökünde yayında olacak.
2. **App Store girişindeki "Developer Website" (Marketing URL) tam olarak aynı
   alan adını gösterecek.** AdMob geliştirici sitesini App Store sayfasından
   okuyor; orada site yoksa dosya doğru olsa bile doğrulama başarısız olur.

Aynı satır Google Play tarafı için de geçerlidir; tek dosya iki mağazaya yeter.

## 🏆 Neden akılda kalır?

- **Tek cümlelik oynanış**: "Dokun, fırla, tutun." Öğrenmesi 5 saniye, ustalaşması haftalar.
- **Müzik = oynanış**: melodiyi oyuncunun kendisi çalar; iyi seri = yükselen nağme.
- **Görsel imza**: karanlık uzayda neon halkalar — küçük ekranda bile anında tanınır.
- **Saygılı model**: reklamsız ilk saat, dürüst premium. İnceleme puanlarını yükselten şey budur.
