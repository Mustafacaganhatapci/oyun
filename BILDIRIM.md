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

**a. APNs anahtarı.** developer.apple.com → Certificates, Identifiers &
Profiles → Keys → yeni anahtar, **Apple Push Notifications service (APNs)**
işaretli. İnen `.p8` dosyası **bir kez** indiriliyor, kaybedersen yenisini
üretmen gerekir. Key ID ve Team ID'yi de not al.

**b. Firebase'e yükle.** Firebase konsolu → Project settings → Cloud
Messaging → Apple app configuration → APNs Authentication Key → `.p8`
dosyasını, Key ID'yi ve Team ID'yi gir.

**c. Xcode.** Hedef → Signing & Capabilities → **+ Capability** →
*Push Notifications*. Ardından **+ Capability** → *Background Modes* →
*Remote notifications* kutusu.

**d. Paket.** Xcode → Package Dependencies → firebase-ios-sdk zaten ekli;
ürün listesinden **FirebaseMessaging**'i de hedefe ekle. Ayarlardaki
"Bildirimler" satırı bu adımı BEKLEMİYOR — yerel hatırlatmalar için zaten
görünüyor; paket yalnızca konsoldan herkese gönderilen yayını açıyor.

**e. Gönder.** Firebase konsolu → Messaging → Create campaign →
Firebase Notification messages. Hedef olarak **Topic** seç ve `all` yaz.
Uygulama, oyuncu ayarlardan izin verdiğinde bu konuya abone oluyor.

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
