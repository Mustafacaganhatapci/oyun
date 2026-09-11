# Duyuru ve bildirim

Oyuncuya haber ulaştırmanın **üç** yolu var.

| | Duyuru kartı | Yerel hatırlatma | Uzaktan yayın |
|---|---|---|---|
| Nereye düşer | Ana menü, oyunu açınca | Kilit ekranı, üstten | Kilit ekranı, üstten |
| Kime ulaşır | Oyunu açan herkese | İzin veren herkese | İzin veren herkese |
| Kurulum | **Yok** | **Yok** | APNs anahtarı (tek seferlik) |
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

Üçüncüsü (herkese tek seferlik serbest metin) **iki adım** uzakta. Kodun ve
projenin tarafında yapılacak bir şey kalmadı:

- [x] `PushManager`, `AppDelegate`, izin akışı, konu aboneliği — hazır
- [x] `FirebaseMessaging` paketi hedefe **bağlandı** (`project.pbxproj`)
- [x] `aps-environment` yetkisi **eklendi** (`Lumo.entitlements`)
- [ ] APNs `.p8` anahtarını üret → **§3a**
- [ ] Anahtarı Firebase'e yükle → **§3b**

Kalan ikisi Apple ve Firebase konsollarında, dosya indirip yüklemekten
ibaret. Yerel hatırlatmalar bunların hiçbirini beklemiyor, bugün çalışıyor.

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
| `appStoreID` | string | **iOS**: varsa "Güncelle" düğmesi çıkar ve App Store'u açar |
| `playStoreId` | string | **Android**: aynı düğme, Play'de bu paketi açar |

`minVersion` güncelleme duyurusunun püf noktası: güncellemeyi almış olan
kişiye "güncelle" demek, kartı hemen kapatılacak bir gürültüye çevirir.

### Hazır blok — 2.2 duyurusu

**iOS ve Android aynı belgeyi okuyor**, iki ayrı duyuru yazmana gerek yok.
Tek fark mağaza düğmesinde: iOS `appStoreID`'ye, Android `playStoreId`'ye
bakıyor. İkisini de yaz, her platform kendininkini alır.

Firestore → `config` → `announcement` belgesine alan alan gir (hepsi
**string**, yalnızca `enabled` **boolean**):

```
enabled       true                      ← BOOLEAN, tırnaksız
id            v2.2
minVersion    2.2
appStoreID    <App Store Connect → App Information → Apple ID>
playStoreId   com.caganhatapci.orbeon

title         Orbeon 2.2 is out
body          Record the game's sounds in your own voice, and meet seven new characters.

title_tr      Orbeon 2.2 yayında
body_tr       Oyunun seslerini kendi sesinle kaydet; yedi de yeni karakter var.

title_de      Orbeon 2.2 ist da
body_de       Nimm die Spielgeräusche mit deiner eigenen Stimme auf — und sieben neue Figuren.

title_es      Orbeon 2.2 ya está
body_es       Graba los sonidos del juego con tu propia voz, y conoce siete personajes nuevos.

title_fr      Orbeon 2.2 est là
body_fr       Enregistre les sons du jeu avec ta propre voix, et découvre sept nouveaux personnages.

title_ja      Orbeon 2.2 が公開
body_ja       ゲームの効果音を自分の声で録音できます。新キャラクターも7体。
```

> **Sürüm numarasını iki yerde birden değiştir.** `id` "kapat" takibi için,
> `minVersion` kimin göreceği için. `minVersion`'ı yanlış yazarsan
> güncellemeyi almış olan kişiye de "güncelle" dersin.

> **`enabled`'ı ancak sürüm mağazada GERÇEKTEN yayına girince true yap.**
> İnceleme aşamasındaki bir sürüm için duyuru göndermek, düğmeye basanı
> hâlâ eski sürümün durduğu bir sayfaya götürür.

**Bunun bir bonusu var:** duyuru belgesi yayına girdiğinde aynı metin, bildirim
izni vermiş oyunculara **dört saat sonra bildirim olarak da düşüyor**
(`syncUpdateReminder`). Yani kartı görüp "sonra" diyene ikinci bir dokunuş.
Bu YEREL bir bildirim: APNs anahtarı, `.p8`, Firebase Messaging — hiçbiri
gerekmiyor. Oyuncu güncellerse ya da kartı kapatırsa bekleyen bildirim
kendiliğinden iptal oluyor.

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

### c. Xcode — capability ✅ yapıldı

`Lumo.entitlements` içine `aps-environment` yazıldı, yani hedef zaten push
yetkili. Xcode'da **Signing & Capabilities** sekmesini açınca "Push
Notifications" satırını orada göreceksin; elle eklemene gerek yok.

Bu satır olmadan `registerForRemoteNotifications()` sessizce başarısız
oluyordu — hata da vermiyor, belirteç de gelmiyor. Aranması en zor arıza
türü, o yüzden dosyaya yazıldı: bir daha kimse tıklamayı unutamaz.

Değer `development` ve öyle **kalmalı**. App Store'a dışa aktarırken Xcode
onu `production` olarak yeniden imzalıyor; tek bir `.p8`'in hem TestFlight'ta
hem yayında çalışmasının sebebi bu.

> **Background Modes → Remote notifications gerekmiyor.** O kutu sessiz
> (içerik-güncelleme) bildirimleri için. Orbeon yalnızca ekrana düşen
> bildirim gönderiyor; işaretlemek App Review'da "bunu ne için
> kullanıyorsun" sorusunu davet etmekten başka bir şey yapmaz.

Ücretli geliştirici hesabı yine de şart: ücretsiz hesap APNs anahtarı
üretemiyor.

### d. Paket ✅ yapıldı

**FirebaseMessaging** hedefe bağlandı (`project.pbxproj`). Xcode'u açtığında
Swift Package Manager paketi kendiliğinden çözüyor; ilk açılışta "Resolving
Package Graph" birkaç saniye sürebilir.

Bunun anlamı: `canImport(FirebaseMessaging)` artık **true**, yani konu
aboneliği gerçekten kuruluyor. Önce false dönüyordu ve `subscribe()` hiçbir
şey yapmadan geçiyordu.

Ayarlardaki "Bildirimler" satırı bu adımı zaten beklemiyordu — yerel
hatırlatmalar için görünüyordu; paket yalnızca konsoldan gönderilen yayını
açıyor.

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

**Önce KENDİ telefonunda dene.** Konu yayını geri alınamıyor: yanlış yazılmış
bir cümleyi `all`'a gönderdikten sonra düzeltmenin yolu yok, ikinci bir
bildirim göndermek de ilkini silmiyor.

Hata ayıklama derlemesinde bildirimleri açtığın an FCM belirteci Xcode
konsoluna düşüyor:

```
FCM BELİRTECİ (tek cihaz testi için): dQw4w9Wg...
```

Onu kopyala → Firebase konsolu → Messaging → kampanyayı yaz → **Send test
message** → kutuya yapıştır → Test. Bildirim yalnızca o telefona düşüyor.
Metni gerçek kilit ekranında gördükten, uzunluğunu ve satır kırılmasını
beğendikten sonra Publish'e bas.

Belirteç yalnızca `DEBUG` derlemesinde yazılıyor ve kişiyi değil kurulumu
adresliyor; uygulamayı silip yeniden kurunca değişiyor.

### f. Dil

Bir konu yayını TEK metin gönderiyor ve cihazın diline göre değişmiyor.
Firebase'in kendi dil hedeflemesi Google Analytics istiyor, o da bu projede
bağlı değil (yalnızca Auth, Firestore ve AdMob var).

Çözüm konunun kendisinde: her cihaz **iki** konuya abone oluyor —
herkesi kapsayan `all` ve kendi dilininki.

| Konu | Kime gider |
|---|---|
| `all` | Herkese, dil fark etmeksizin |
| `all_tr` | Telefonu Türkçe olanlara |
| `all_en` | İngilizce — desteklenmeyen diller de buraya düşüyor |
| `all_de` `all_es` `all_fr` `all_ja` | Kendi dillerine |

Yani Türkçe metni `all_tr`'ye, İngilizceyi `all_en`'e gönderiyorsun: iki
kampanya, iki dil, kimse yabancı bir cümleyle karşılaşmıyor. Dilin fark
etmediği bir haber varsa (bakım, sunucu sorunu) `all` yetiyor.

Konsolda Target adımında Topic kutusuna hangisini yazarsan ona gidiyor.
`all`'a gönderirsen dil konularına AYRICA gönderme — aynı kişiye iki
bildirim düşer.

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

---

## 4. İnsanlar nereye kadar geliyor?

Kampanya ilerlemesi bugüne kadar hiçbir yere yazılmıyordu: sıralama yalnızca
sonsuz mod ve hız turunu tutuyor. Yani bir bölüm çok zorsa ya da insanlar
12'de toptan bırakıyorsa bunu ancak biri yazıp söylerse öğreniyorduk.

Artık Firestore'da iki belge var:

| Belge | Ne tutuyor |
|---|---|
| `stats/progress_ios` | Bölüm başına: kaç iPhone oyuncusu o bölümü bitirdi |
| `stats/progress_android` | Aynısı, Android için |

Alanlar şöyle görünüyor:

```
lvl_001: 4820
lvl_002: 4310
lvl_005: 3105
lvl_010:  1890
lvl_020:   640
```

Konsolda belgeyi açtığında düşüş eğrisini doğrudan okuyorsun. İki sayı
arasındaki sert düşüş, oranın çok zor ya da bozuk olduğunu söyler.

**Kim olduğu yazılmıyor.** Sayaç `FieldValue.increment` ile artıyor, yani
istemci sayıyı okumadan bir ekliyor; oyuncu kimliği hiç gönderilmiyor.
Belge okumaya da kapalı (`firestore.rules` → `match /stats/{doc}`), yalnızca
konsoldan görünüyor.

**Her bölüm cihaz başına bir kez sayılıyor.** Aynı bölümü on kez oynayan biri
eğriyi on kat bozmuyor: ölçülen "kaç kişi buraya geldi", "kaç kez oynandı"
değil.

**Platformlar ayrı belgede.** İki eğri farklı olabilir ve tek belgeye yazmak
ikisini karıştırırdı. Ayrıca tek bir Firestore belgesi saniyede ~1 yazma
kaldırıyor; ikiye bölmek o sınırı da ikiye bölüyor. Oyuncu sayısı çok
artarsa bu sınır yeniden düşünülmeli.

> **Kuralları yeniden yayınlaman gerekiyor.** `firestore.rules` dosyasına
> `stats` bloğu eklendi; Firebase konsolu → Firestore → Rules → yapıştır →
> **Publish**. Yayınlanmazsa sayaç yazılamaz (oyun etkilenmez, sessizce
> atlanır) ve belgeler hiç oluşmaz.

Belgeleri elle oluşturmana gerek yok: ilk oyuncu bir bölüm bitirdiğinde
kendiliğinden oluşuyorlar.
