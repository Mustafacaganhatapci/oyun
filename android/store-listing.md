# Play Console — hazır metinler

Aşağıdakiler doğrudan kopyalanabilir. Karakter sınırları Play Console'un
kabul ettiği üst sınırlardır; yazılanlar sınırın altındadır.

---

## Uygulama adı (en fazla 30 karakter)

```
Orbeon
```

---

## Kısa açıklama (en fazla 80 karakter)

**Türkçe** (68)
```
Halkadan halkaya sıçra, ışığı topla. Tek dokunuşla oynanan yörünge oyunu.
```

**English** (72)
```
Hop ring to ring and chase the light. A one-tap orbit game with 120 levels.
```

**Deutsch** (76)
```
Spring von Ring zu Ring und sammle das Licht. Ein Orbit-Spiel mit einem Tipp.
```

**Français** (77)
```
Saute d'anneau en anneau et attrape la lumière. Un jeu d'orbite à une touche.
```

**Español** (78)
```
Salta de anillo en anillo y atrapa la luz. Un juego de órbita con un toque.
```

**日本語** (39)
```
リングからリングへ跳んで光を集める、ワンタップの軌道ゲーム。
```

---

## Tam açıklama (en fazla 4000 karakter)

### Türkçe

```
Işık bir yörüngede döner. Ekrana dokun, bir sonraki halkaya fırla. Hepsi bu — ama bırakmak kolay değil.

Orbeon tek parmakla oynanan bir zamanlama oyunu. Küre halkanın çevresinde döner; doğru anda dokunursan teğet çizip bir sonraki halkaya tutunur. Yanlış anda dokunursan boşluğa savrulursun.

◆ 120 EL YAPIMI BÖLÜM
Sakin bir başlangıçtan ustalık isteyen sonlara uzanan bir eğri. Yol boyunca dönen kırmızı tehlike yayları, ileri geri süzülen halkalar, süreli bölümler ve "oyalanma yok" turları açılır. Her yeni mekanik oyunun içinde, oynatarak öğretilir — duvar duvar yazı okumazsın.

◆ SONSUZ MOD
Yukarı tırmandıkça hızlanan, sonu olmayan bir tırmanış. Nereye kadar?

◆ HIZ KOŞUSU
İlk on bölüm, tek seferde, saniyeye karşı. Dünya sıralamasında yerini al.

◆ GÜNLÜK ÖDÜLLER VE GÖREVLER
Her gün gir, üst üste geldikçe artan yıldızları topla. Her gün yenilenen üç görev daha var.

◆ 14 KARAKTER, 10 TEMA
Yıldız, kristal, kuyruklu yıldız, ateşböceği, bulut… Topladığın yıldızlarla aç. Premium ile küreye kendi fotoğrafını da koyabilirsin.

◆ DÜNYA SIRALAMASI
Sonsuz mod ve hız koşusu için ayrı tablolar.

◆ HİÇBİR SATIN ALMA AVANTAJ VERMEZ
Orbeon'da pay-to-win yoktur. Premium reklamları kaldırır ve kozmetik açar — oynanışa dokunmaz. İlk on bölümde hiç reklam gösterilmez.

◆ İNTERNETSİZ DE OYNANIR
Sıralama dışında her şey çevrimdışı çalışır.

Türkçe, İngilizce, Almanca, Fransızca, İspanyolca ve Japonca desteklenir.
```

### English

```
The light travels on an orbit. Tap the screen and launch to the next ring. That is the whole game — and it is hard to put down.

Orbeon is a one-thumb timing game. The orb circles a ring; tap at the right moment and it flies off on a tangent and catches the next one. Tap at the wrong moment and it sails into the dark.

◆ 120 HANDMADE LEVELS
A curve that starts calm and ends demanding. Along the way you unlock rotating red hazard arcs, rings that drift back and forth, timed levels and rounds where lingering kills you. Every new mechanic is taught inside the game, by playing — no walls of text.

◆ ENDLESS MODE
A climb with no ceiling that speeds up the higher you get. How far can you carry the light?

◆ SPEED RUN
The first ten levels, one sitting, against the clock. Take your place on the world board.

◆ DAILY REWARDS AND MISSIONS
Check in each day and collect a growing pile of stars. Three fresh missions land every day on top of that.

◆ 14 CHARACTERS, 10 THEMES
Star, crystal, comet, firefly, cloud and more, unlocked with the stars you collect. Premium also puts your own photo inside the orb.

◆ WORLD RANKING
Separate boards for endless mode and speed run.

◆ NO PURCHASE GIVES AN ADVANTAGE
There is no pay-to-win in Orbeon. Premium removes ads and unlocks cosmetics — it never touches gameplay. The first ten levels are always ad-free.

◆ PLAYS OFFLINE
Everything except the ranking works without a connection.

Available in English, Turkish, German, French, Spanish and Japanese.
```

---

## Uygulama içi ürünler

**Play Console → Para kazanma → Ürünler → Uygulama içi ürünler → Ürün oluştur**

> **Ön koşul:** Ürün oluşturabilmek için önce en az bir test kanalına
> (Dahili test yeterli) imzalı bir AAB yüklemiş olman gerekir. Yüklemeden
> önce bu ekran kilitli gelir.

> **iOS'tan önemli fark:** Play Console'da "tüketilebilir mi" diye bir
> seçenek **yoktur**. Bunu uygulama belirler: `BillingManager` bahşişleri
> `consumeAsync` ile tüketir, premium'u `acknowledgePurchase` ile onaylar.
> Yani konsolda üçü de sıradan "tek seferlik ürün" olarak oluşturulur;
> bahşişlerin tekrar alınabilmesi koddan gelir.

Kimlikler `services/BillingManager.kt` içindekilerle **birebir** aynı olmalı,
yoksa ürünler uygulamada görünmez.

| Ürün kimliği | Önerilen fiyat |
|---|---|
| `orbeon.premium` | 1,99 USD |
| `orbeon.tip.small` | 0,99 USD |
| `orbeon.tip.big` | 4,99 USD |

Play Console'da ad en fazla 55, açıklama en fazla 200 karakterdir; aşağıdaki
metinlerin hepsi sınırın altındadır (App Store Connect'te sınır 30/45 olduğu
için orada bazı açıklamalar kısaltılmıştı — burada tam hâlleri kullanılır).

### `orbeon.premium`

| Dil | Ad | Açıklama |
|---|---|---|
| Türkçe | Orbeon Premium | Tüm reklamları sonsuza dek kaldırır, 8 özel tema ve foto küreyi açar. Oynanışa hiçbir etkisi yoktur. |
| English | Orbeon Premium | Removes all ads forever and unlocks 8 exclusive themes plus the photo orb. It never affects gameplay. |
| Deutsch | Orbeon Premium | Entfernt alle Werbung dauerhaft, schaltet 8 exklusive Themes und die Foto-Kugel frei. Ohne Einfluss aufs Spiel. |
| Français | Orbeon Premium | Supprime toutes les pubs à jamais et débloque 8 thèmes exclusifs et l'orbe photo. Sans effet sur le jeu. |
| Español | Orbeon Premium | Elimina todos los anuncios para siempre y desbloquea 8 temas exclusivos y el orbe con foto. No afecta al juego. |
| 日本語 | Orbeon プレミアム | 広告を永久に削除し、限定テーマ8種とフォトオーブを解放します。ゲーム内容には影響しません。 |

### `orbeon.tip.small`

| Dil | Ad | Açıklama |
|---|---|---|
| Türkçe | Kahve — Evde | Geliştiriciye küçük bir bahşiş |
| English | Coffee at home | A small tip for the developer |
| Deutsch | Kaffee zuhause | Ein kleines Trinkgeld für den Entwickler |
| Français | Café à la maison | Un petit pourboire pour le développeur |
| Español | Café en casa | Una pequeña propina para el desarrollador |
| 日本語 | おうちコーヒー | 開発者へのささやかなチップ |

### `orbeon.tip.big`

| Dil | Ad | Açıklama |
|---|---|---|
| Türkçe | Kahve — Kafede | Geliştiriciye büyük bir bahşiş (sandalye dahil) |
| English | Coffee at a café | A big tip for the developer (chairs included) |
| Deutsch | Kaffee im Café | Ein großes Trinkgeld für den Entwickler (Stühle inklusive) |
| Français | Café au bistrot | Un grand pourboire pour le développeur (chaises comprises) |
| Español | Café en cafetería | Una gran propina para el desarrollador (sillas incluidas) |
| 日本語 | カフェでコーヒー | 開発者へのたっぷりチップ（椅子代込み） |

---

## Veri güvenliği formu

iOS'taki App Privacy beyanıyla aynı içerik:

| Veri | Ne için | Kimliğe bağlı | İzleme (reklam) |
|---|---|---|---|
| Cihaz/reklam kimliği | Reklamcılık | Hayır | **Evet** |
| Uygulama etkileşimi | Reklamcılık, analiz | Hayır | **Evet** |
| Kullanıcı kimliği (sıralama adı) | Uygulama işlevi | **Evet** | Hayır |

Toplanmayanlar: konum, kişiler, sağlık, finans, mesajlar, dosyalar, kişisel
bilgiler. Kilitlenme/analiz SDK'sı eklenmedi — o kutuları işaretleme.

Veriler aktarım sırasında şifrelenir (Firestore HTTPS). Kullanıcı silme talebi
için: sıralama kaydı cihazda üretilen kimliğe bağlıdır; destek e-postasıyla
kaldırma sağlanır.

---

## İçerik derecelendirmesi

Şiddet, korku, cinsellik, kumar, madde içeriği yoktur. Kullanıcılar arası
iletişim yoktur; yalnızca sıralamada kullanıcının seçtiği takma ad görünür.
Dijital satın alma **vardır**, reklam **vardır** — anketi buna göre doldur.
Beklenen sonuç: **3+ / Herkes**.

---

## Sürüm notları (What's new)

**Türkçe**
```
Orbeon'un ilk Android sürümü. 120 bölüm, sonsuz mod, hız koşusu, günlük ödüller ve görevler, 14 karakter, 10 tema ve dünya sıralaması. İyi eğlenceler!
```

**English**
```
Orbeon's first Android release. 120 levels, endless mode, speed run, daily rewards and missions, 14 characters, 10 themes and world rankings. Have fun!
```
