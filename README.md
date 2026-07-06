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

### Game Center (dünya sıralaması)

Kod hazır (`GameCenterService.swift`, entitlement ekli); yayına almak için:
1. App Store Connect > uygulaman > Services > Game Center'ı etkinleştir.
2. İki liderlik tablosu oluştur: `lumo.endless` (yüksek skor, tamsayı) ve
   `lumo.speedrun` (düşük süre kazanır; değer saniyenin yüzde biri cinsinden gönderilir).
3. Cihazda Game Center hesabı açık olmalı. Kimlik doğrulama başarısızsa oyun sessizce çevrimdışı çalışır.
Not: İmzalama sorunu yaşarsan Signing & Capabilities'ten Game Center yeteneğini geçici kaldırabilirsin.

### Gerçek reklamları (AdMob) açmak

Kod SDK'sız da tam çalışır (DEBUG'da yer tutucu reklam, RELEASE'te reklamsız akış).
Yayın öncesi:

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

## 🏆 Neden akılda kalır?

- **Tek cümlelik oynanış**: "Dokun, fırla, tutun." Öğrenmesi 5 saniye, ustalaşması haftalar.
- **Müzik = oynanış**: melodiyi oyuncunun kendisi çalar; iyi seri = yükselen nağme.
- **Görsel imza**: karanlık uzayda neon halkalar — küçük ekranda bile anında tanınır.
- **Saygılı model**: reklamsız ilk saat, dürüst premium. İnceleme puanlarını yükselten şey budur.
