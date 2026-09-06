# Duyuru ve bildirim

Oyuncuya haber ulaştırmanın **üç** yolu var.

| | Duyuru kartı | Yerel hatırlatma | Uzaktan yayın |
|---|---|---|---|
| Nereye düşer | Ana menü, oyunu açınca | Kilit ekranı, üstten | Kilit ekranı, üstten |
| Kime ulaşır | Oyunu açan herkese | İzin veren herkese | İzin veren herkese |
| Kurulum | **Yok** | **Yok** | APNs anahtarı + Xcode + paket |
| Ne zaman gider | — | Zamanı kod belirliyor | Sen gönderince |
| Yayınlama | Firestore'da bir belge | — | Firebase konsolundan gönderi |

İlk ikisi **bugün çalışıyor**. Ayarlardaki bildirim anahtarı artık her zaman
görünüyor: açan kişi izin verdiği an iki yerel hatırlatma kuruluyor.

**Haftalık yarış** — sıralama sıfırlanmadan bir gün önce, her hafta aynı gün
ve saatte. Hafta tam yedi gün olduğu için tekrarlayan takvim tetiği kayamıyor.
Gece yarısına denk gelirse akşam 19:00'a çekiliyor.
`PushManager.scheduleWeeklyRaceReminder()`

**Yeni sürüm** — aşağıdaki duyuru belgesi yayındaysa, aynı metin dört saat
sonra bildirim olarak da düşüyor: kartı görüp "sonra" diyene ikinci bir
dokunuş. Oyuncu güncellerse ya da kartı kapatırsa bekleyen bildirim iptal
oluyor. `PushManager.syncUpdateReminder(title:body:)`

Üçüncüsü (herkese tek seferlik serbest metin) hâlâ APNs kurulumunu bekliyor;
`FirebaseMessaging` paketi projede olmadığı sürece `canReceiveBroadcast`
false dönüyor ve konu aboneliği sessizce atlanıyor. Yerel hatırlatmalar bundan
etkilenmiyor.

---

## 1. Duyuru kartı (kurulum gerektirmez)

Firebase konsolu → Firestore → `config` koleksiyonu → `announcement` belgesi.
Alanlar:

| Alan | Tür | Ne işe yarar |
|---|---|---|
| `enabled` | boolean | `false` ise hiçbir şey gösterilmez |
| `id` | string | "Kapat" takibi bunun üzerinden. Metni değiştirip id'yi de değiştirirsen daha önce kapatanlar tekrar görür |
| `title` | string | Başlık (İngilizce taban) |
| `body` | string | Metin |
| `title_tr`, `body_tr` | string | Türkçe karşılık. `_de`, `_es`, `_fr`, `_ja` de olur |
| `minVersion` | string | "2.1". Uygulama bu sürümde ya da üstündeyse **gösterilmez** |
| `appStoreID` | string | Varsa "Güncelle" düğmesi çıkar ve App Store'u açar |

`minVersion` güncelleme duyurusunun püf noktası: güncellemeyi almış olan
kişiye "güncelle" demek, kartı hemen kapatılacak bir gürültüye çevirir.

Örnek — 2.1 çıktığında:

```
enabled:    true
id:         "v2.1"
minVersion: "2.1"
appStoreID: "6753159821"        ← kendi App Store kimliğin
title:      "Orbeon 2.1 is out"
body:       "Four new characters and ranks on the weekly board."
title_tr:   "Orbeon 2.1 yayında"
body_tr:    "Dört yeni karakter ve haftalık tabloda rütbeler."
```

Duyuruyu kaldırmak için `enabled` alanını `false` yap. Kural değişikliği
gerekmiyor: `config/{doc}` zaten herkese okunur, yalnızca konsoldan yazılır.

---

## 2. Yerel hatırlatmalar (kurulum yok)

Haftalık yarış ve yeni sürüm hatırlatmaları hiçbir şey beklemiyor. Oyuncu
Ayarlar'dan bildirimleri açtığı an ikisi de kuruluyor. Yapman gereken tek
şey: hiçbir şey.

---

## 3. Uzaktan yayın (bir kereye mahsus kurulum)

Herkese aynı anda serbest metin göndermek — yalnızca bu Apple tarafındaki
anahtarı istiyor. Kod hazır.

Bu projenin sayıları (her adımda lazım olacak):

| | |
|---|---|
| Bundle ID | `com.caganhatapci.lumo` |
| Firebase projesi | `lumo-890fb` |
| Sender ID | `1062323753593` |
| Konu (topic) | `all` |

### a. APNs anahtarı üret

developer.apple.com → Certificates, Identifiers & Profiles → soldan **Keys**
→ mavi **+**. Ad ver ("Orbeon Push" yeter), **Apple Push Notifications
service (APNs)** kutusunu işaretle → Continue → Register.

İnen `.p8` dosyası **bir kez** iniyor. Kaybedersen o anahtar bir daha
indirilemez, yenisini üretmen gerekir (eskisini iptal etmeden de olur, bir
hesapta iki APNs anahtarı bulunabiliyor).

Yanına iki şey daha not al:
- **Key ID** — anahtarın sayfasında yazan 10 karakter
- **Team ID** — sağ üstteki hesap adının altında ya da Membership sayfasında

Bu anahtar hem geliştirme hem yayın için geçerli. Eski `.p12` sertifikaların
aksine ortam ayrımı yok, TestFlight ve App Store aynı anahtarla çalışıyor.

### b. Firebase'e yükle

Firebase konsolu → dişli → Project settings → **Cloud Messaging** sekmesi →
aşağıda **Apple app configuration** → `com.caganhatapci.lumo` satırı →
**APNs Authentication Key** → Upload.

Üç alan: `.p8` dosyası, Key ID, Team ID.

Bu satırda uygulama görünmüyorsa iOS uygulaması projeye eklenmemiş demektir;
`GoogleService-Info.plist` zaten bu projeden indiği için normalde görünür.

### c. Xcode — iki capability

Hedef → **Signing & Capabilities** → **+ Capability**:
1. **Push Notifications**
2. **Background Modes** → içinden **Remote notifications** kutusu

Otomatik imzalama açıksa Xcode App ID'ye push yetkisini kendisi ekliyor.
Ücretli geliştirici hesabı şart — ücretsiz hesapta Push Notifications
capability listede çıkmıyor.

### d. Paket

Xcode → hedef → General → Frameworks, Libraries, and Embedded Content → **+**
→ listeden **FirebaseMessaging**. Paket (firebase-ios-sdk) zaten ekli,
yalnızca bu ürün hedefe bağlı değil.

Ayarlardaki "Bildirimler" satırı bu adımı BEKLEMİYOR — yerel hatırlatmalar
için zaten görünüyor; paket yalnızca konsoldan gönderilen yayını açıyor.

### e. Dene

**Gerçek cihazda.** Simülatör APNs belirteci almıyor.

1. Derle, Ayarlar → Bildirimler'i aç, izin ver
2. Console.app → cihazını seç → "Orbeon" ile süz
3. Firebase konsolu → Messaging → Create campaign → **Firebase Notification
   messages** → başlık/metin yaz → Next → Target: **Topic** → `all` →
   Schedule: Now → Review → Publish

Konu aboneliğinin sunucuya işlemesi birkaç dakika sürebiliyor; ilk denemede
gelmezse beş dakika bekleyip tekrar gönder. Uygulama ÖNDEYKEN de banner
çıkıyor (`AppDelegate`'teki `willPresent`).

Tek bir cihaza test göndermek istersen konsolda "Send test message" kutusuna
FCM belirtecini yapıştırman gerekiyor; belirteci koda `Messaging.messaging()
.token()` çağrısı eklemeden görmenin yolu yok, o yüzden pratikte konu
yayınıyla denemek daha kolay.

### f. Dil

Konu yayını TEK metin gönderiyor, cihazın diline göre değişmiyor. Uygulama
içindeki her şey yerelleştirilmiş durumda ama bu değil. Oyuncuların çoğu
Türkiye'deyse Türkçe yaz; karışıksa İngilizce yaz ya da iki cümleyi alt alta
koy. Firebase konsolunda dile göre ayrı kampanya açmak da mümkün, hedefleme
sekmesinden "Language" koşulu ekleniyor.

### Bilerek yapılmayan şey

İzin **açılışta istenmiyor.** Oyunu ilk kez açan birinin karşısına çıkan
izin kutusu çoğunlukla reddediliyor ve iOS bir daha sormuyor — o oyuncuya
bir daha asla bildirim gönderemezsin. Ayarlardaki anahtar varsayılan
kapalı; oyuncu açtığı an izin isteniyor. Apple da tanıtım amaçlı bildirim
için açık rıza şart koşuyor (App Review Guideline 4.5.4), anahtar o rızanın
kendisi.

Reddedildiyse uygulama içinden izin yeniden istenemez; Ayarlar'daki satır o
durumda iOS Ayarları'na götüren bir bağlantıya dönüşüyor.

### Sıklık

Konu yayını herkese aynı anda gider ve geri alınamaz. Ayda bir-iki
gönderiden fazlası bildirimlerin toptan kapatılmasına yol açıyor; kapatan
oyuncu geri açmıyor.
