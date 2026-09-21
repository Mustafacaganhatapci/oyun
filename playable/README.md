# Oynanabilir reklam (playable ad)

`orbeon-playable.html` — tek dosya, dış bağlantı yok, 29 KB (gzip 9 KB).
Üç bölüm oynatıp indirme kartıyla bitiyor.

## Yayına vermeden önce

**1. App Store kimliğini gir.** Dosyanın başındaki `CONFIG.appStoreId`
şu an boş; boş kalırsa iOS tıklaması App Store'un arama sayfasına düşüyor.

```js
appStoreId: "1234567890"
```

Bulacağın yer: App Store Connect → Orbeon → **App Information** →
**General Information** → **Apple ID**. (Aynı sayı Firestore'daki
`config/announcement` belgesinde de lazım, `YAYIN.md` 5b.)

**2. Dili seç.** `CONFIG.lang` boşken cihazın dilinden seçiliyor
(tr/en/es, tanımadığı dilde İngilizce). Tek dile sabitlemek istersen
`"tr"` yaz. Test için `?lang=es` de çalışıyor.

**3. Dikey yükle.** Oyun alanı 1:2.05 oranında kurulu. Yatayda çalışıyor
ama ince bir şeride sıkışıyor — ağın panelinde yönü **portrait** seç.

## Ne gösteriyor

| Bölüm | Konu |
|---|---|
| 1 | Dokun–fırlat, kapı en az bir yıldız istiyor |
| 2 | Tehlike yayı: ilk tur yakmıyor, yeşil eriyince yakıyor |
| 3 | **Kırmızı tuzak kapı** — 2.3'ün asıl konusu |

Bitiş kartı: "Geri kalan 254 bölüm seni bekliyor" + indirme düğmesi.
Oyun sırasında da alt tarafta sürekli bir indirme düğmesi duruyor
(çoğu ağ bunu şart koşuyor).

## Tıklama köprüleri

`openStore()` sırayla deniyor: MRAID (AppLovin, ironSource, Unity,
Vungle) → `FbPlayableAd` (Meta) → `ExitApi` (Google Ads) →
`window.gameend` → `postMessage` → `window.open`. Hangi ağa verirsen ver
ek bir şey yapman gerekmiyor. MRAID'de reklam "loading" durumundayken
oyun başlatılmıyor, ağ hazır deyince başlıyor.

## Oyundan farkları — bilerek

Mekanik `GameScene.swift` ile birebir: uçuş hızı ekran genişliğinin
1,55 katı/sn, yakalama kürenin halka çemberine girmesiyle, tehlike
müsamahası tam bir tur, ölünce başlangıç halkasına dönüş. Üç şey farklı:

- **Halkalar daha büyük ve yavaş.** Oyunun kendi ölçüleriyle ölçtüğümde
  başlangıç halkasından 240 dokunuş anının 217'si ıskalıyordu. Oyunda bu
  doğru, öğrenmek için vakit var; on beş saniyelik reklamda değil.
  Şimdiki ölçüde nişan penceresi 0,8 saniye.
- **Nişan çizgisi hep açık.** Oyunda yalnızca öğreticide var.
- **Ölüm sonrası bekleme 0,42 sn** (oyunda 0,55).

## Yeniden ayarlamak istersen

Yıldızlar halkaların **çemberinde** duruyor, koridorların ortasında
değil. Küre halkadan teğet ayrıldığı için merkezden merkeze giden
çizgide hiç ilerlemiyor; oraya konan yıldız hiçbir zaman toplanmıyor
(ölçtüm: toplama ihtimali %0). Çemberdeki yıldızı küre dönerken
kendiliğinden topluyor ve kapı o anda yanıyor — oyunun kendi öğreticisi
de bunu yapıyor. `LEVELS` içindeki `lumens` değerlerini değiştireceksen
bu kuralı bozma.
