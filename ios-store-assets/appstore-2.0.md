# Orbeon 2.0 — mağaza metinleri

Diller: **TR · EN · ES**. Karakter sınırları App Store'a göre:
promosyon metni 170, açıklama 4000, yenilikler 4000, anahtar kelimeler 100.

Mağazadaki son sürüm **1.6** idi; 1.7 hiç yayınlanmadı. Bu yüzden "Yenilikler"
1.6'dan bu yana biriken her şeyi kapsıyor — 1.7 için yazılmış maddeler de burada.

Ekran görüntüleri: `appstore-{dil}-{1..5}-{sahne}.png` (1320×2868) ve
`6.5-inch/` (1242×2688). Beşi de `build_shots.py` ile üretiliyor —
metin değişince yeniden çalıştır, elle düzenleme.

Sayılar oyundan: **257 bölüm, 806 yıldız, 22 karakter, 10 tema, 6 rütbe.**
Değişirlerse buradaki her üç dili de güncelle.

---

## TÜRKÇE

### Promosyon metni (170)
Atlayış sesini kendi sesinle kaydet — kombo yükseldikçe incelir, sonra geri
iner. 257 bölüm, 806 yıldız, toplandıkça kendiliğinden açılan 22 karakter.

### Anahtar kelimeler (100)
orbit,halka,tek dokunuş,refleks,zamanlama,arcade,minimal,yörünge,küre,beceri,sonsuz,sıralama

### Açıklama
Bir küre halkanın çevresinde döner. Sen yalnızca ne zaman bırakacağını
seçersin. Tek kural bu — geri kalanı zamanlama.

**HALKADAN HALKAYA**
Dokun, küre teğet fırlar. Doğru anı yakalarsan bir sonraki halkaya tutunur.
Erken bırakırsan boşluğa gidersin.

**KIRMIZIYA DOKUNMA**
Halkaların üstünde dönen tehlike yayları var. Ama ilk turda yakmazlar: yayın
üstündeki yeşil kaplama, sen dönerken iki ucundan erir. Yeşil bittiği an yay
silahlanır. Geri sayım ayrı bir göstergede değil — yayın kendi üstünde.

**MELODİYİ SEN ÇALIYORSUN**
Her kusursuz atlayış bir sonraki notayı çalar. Dizi yükselir, tepeye varınca
aynı yoldan iner ve yeniden çıkar; uzun bir seri, farkında olmadan bestelediğin
bir ezgidir. Premium oyuncular bu seslerin yerine kendi kayıtlarını koyabilir —
kendi "hop"un da komboyla birlikte incelip kalınlaşır.

**HER BÖLÜM AYNI DEĞİL**
Süreli bölümlerde kapıya yetişmen gerekir. Topla-bitir bölümlerinde kapı,
haritadaki bütün ışıkları toplayana kadar kilitli kalır. Bazı bölümlerde tek
bir dev yıldız vardır: dört eder, ama hattından sapmayı göze almalısın. Her
altı bölümde bir bonus turu gelir: kapı yok, süre dolana kadar topla.

**YILDIZ TOPLA, KARAKTER AÇ**
257 bölüm, 806 yıldız, 22 karakter. Yıldızlar harcanmaz — biriktikçe eşikleri
geçersin ve her eşikte yeni bir küre kendiliğinden açılır. Kilitli olanları
göremezsin, yalnızca ne kadar kaldığını bilirsin.

**SONSUZ MOD, HIZ TURU VE HAFTALIK SIRALAMA**
Sonsuz modda yukarı çıktıkça halkalar küçülür ve hızlanır. Hız turunda ilk on
bölümü ne kadar hızlı bitirdiğin sayılır. İkisinin de skoru haftalık tabloya
yazılır ve tablo altı rütbeye ayrılır: Kıvılcım, Kor, Fener, Pulsar, Kuazar,
Zirve. Tablo her pazartesi sıfırlanır; haftayı ilk üçte bitirenler yıldız ve
yalnızca kazanılabilen şampiyon küresini alır.

**ERİŞİLEBİLİRLİK**
Renk körlüğü modu: oynanışı belirleyen renkler her renk körlüğü türünde
ayrışan bir palete geçer, tehlike yayları renge ek olarak çentiklerle
işaretlenir. On arka plan teması, 22 karakter.

Reklamlar isteğe bağlıdır ve oynanışa karışmaz. İnternetsiz de oynanır.
Hiçbir satın alma oyunu kolaylaştırmaz — Orbeon'da pay-to-win yoktur.

### Yenilikler (2.0)
Bu sürümde en büyük yenilik: premium oyuncular oyunun seslerini kendi
sesleriyle değiştirebiliyor.

KENDİ SESLERİN (PREMIUM)
• Atlayış, yıldız, can eksilme, ölüm ve bölüm bitirme sesini kendin kaydet.
• Kayıt 3-2-1 geri sayımından sonra başlıyor.
• Atlayış kaydın komboyla incelip geri kalınlaşıyor.
• Kayıtlar telefonunda kalıyor, hiçbir yere yüklenmiyor.

SIRALAMA
• Haftalık tablo artık altı rütbeye bölünüyor: Kıvılcım'dan Zirve'ye.
• Tablo yüz satırla açılıyor, "daha fazla göster" ile uzuyor.
• Rütbeni internet olmadan da görebiliyorsun.

KARAKTERLER
• Yedi yeni küre: Ay, Atom, Nova, Gezegen, Şimşek, Damla, Hayalet.
• 620 yıldızdan sonrası ödülsüzdü. Artık son yıldıza kadar eşik var ve
  arada 90 yıldızdan uzun boşluk kalmıyor.

SES VE TİTREŞİM
• Atlayış sesi uzun komboda tavan yapmıyor; yükselip aynı yoldan iniyor.
• Can eksilmesinin ayrı bir sesi var.
• Sonsuz modda ölünce iki ses üst üste biniyordu.
• Titreşim, uygulamayı arka plana alıp geri döndükten sonra da çalışıyor.
• Hızlı seride sesler birbirini kesiyordu, düzeldi.

ÖĞRETİCİ VE ANLATIM
• Öğretici artık atlayışta sayı sınırı olmadığını, sarı yıldızların karakter
  açtığını ve yeşilden kırmızıya dönen yayların ne yaptığını da gösteriyor.
• Bonus turuna ilk girişte ne olduğu anlatılıyor.
• 10. bölümde sonsuz mod ile hız turunun açıldığı duyuruluyor.

EKRANLAR
• Kişiselleştir, Premium ve Ayarlar üç ayrı ekrana ayrıldı.
• Karakterler, arka planlar ve kendi seslerin aynı ekranda.
• Ayarlarda görüş ve öneri kutusu.
• İnternet yoksa ne olduğunu söyleyen kısa bir not.

GÖRÜNÜM
• Halkalar, zemin ve küre nötr griye çekildi. Tek doygun renk tehlike kırmızısı.
• Kapı, tehlike ve yıldız renkleri bütün temalarda aynı.
• Yeni logo ve uygulama ikonu.
• Alev karakteri gerçekten alev oldu.

OYNANIŞ
• Tehlike yayları ilk turda yakmıyor. Üstündeki yeşil eriyerek ne zaman
  silahlanacağını gösteriyor.
• Kampanya 257 bölüm, 806 yıldız.
• Karakterler satın alınmıyor, yıldız eşiğinde kendiliğinden açılıyor.
• Renk körlüğü modu.
• Premium'a sonsuz modda tur başına bir can.
• Sonsuz modda yeniden başlat düğmesi.
• Sonsuz modda 20. halkadan sonra her on iki halkada bir, halkanın üstünde
  can kalbi. En fazla üç can.
• Hız turunda kapı, yıldızlar toplanmadan açılmıyor.
• Premium kodu girme alanı.
• Bahşiş bırakan premium'u da alıyor.

DÜZELTMELER
• Haftalık tabloda kendi haftalık skorun yerine tüm zamanlar rekorun görünüyordu.
• Müziği kapatıp uygulamayı yeniden açınca ayar unutuluyordu.
• Ana menüdeki logo küresi zamanla aşağı kayıyordu.
• Satın alırken bekleme göstergesi yoktu.
• Sonsuz modda boşluğa atılan küre geç ölüyordu.
• Açık kapının üstünde beklerken bölüm bitmiyordu.
• Süresiz bölümlerde 0'da donmuş sayaç görünüyordu.

---

## ENGLISH

### Promotional text (170)
Record the hop in your own voice — it still rises with your combo, then comes
back down. 257 levels, 806 stars, 22 characters that unlock as you collect.

### Keywords (100)
orbit,ring,one tap,reflex,timing,arcade,minimal,orb,skill,endless,leaderboard,precision

### Description
An orb circles its ring. You only choose when to let go. That is the whole
rule — the rest is timing.

**RING TO RING**
Tap and the orb flies off on a tangent. Time it well and it catches the next
ring. Let go early and you sail into the void.

**NEVER TOUCH THE RED**
Hazard arcs rotate on the rings. But they don't burn on the first lap: a green
cover sits on the arc and melts away from both ends while you circle. The
moment the green runs out, the arc is armed. The countdown isn't on a separate
gauge — it's on the arc itself.

**YOU PLAY THE MELODY**
Every clean hop sounds the next note. The scale climbs, turns at the top and
comes back down the same way — a long streak is a tune you wrote without
noticing. Premium players can replace those sounds with their own recordings,
and your own "hop" rises and falls with the combo too.

**NOT EVERY LEVEL IS THE SAME**
Timed levels want you at the gate before the clock runs out. Collect levels
keep the gate locked until you've swept every light off the map. Some levels
hold a single giant star: worth four, but you have to leave your line to reach
it. Every sixth level is a bonus round — no gate, just collect until time is up.

**COLLECT STARS, UNLOCK CHARACTERS**
257 levels, 806 stars, 22 characters. Stars are never spent — as they add up
you cross thresholds, and at every threshold a new orb unlocks on its own.
Locked ones stay hidden; you only know how far away they are.

**ENDLESS, SPEED RUN AND THE WEEKLY BOARD**
In Endless the rings get smaller and faster the higher you climb. Speed Run
counts how fast you clear the first ten levels. Both go on the weekly board,
which is split into six ranks: Spark, Ember, Beacon, Pulsar, Quasar, Zenith.
The board resets every Monday, and finishing the week in the top three wins
stars plus the champion orb — the one orb that can only be won.

**ACCESSIBILITY**
Colorblind mode switches the gameplay colours to a palette that stays distinct
for every kind of colour blindness, and marks hazards with notches as well as
colour. Ten background themes, 22 characters.

Ads are optional and never interrupt a run. The game plays offline. No purchase
makes it easier — there is no pay-to-win in Orbeon.

### What's New (2.0)
The headline this time: premium players can replace the game's sounds with
their own voice.

YOUR OWN SOUNDS (PREMIUM)
• Record the hop, the star, the life lost, the death and the level complete.
• Recording starts after a 3-2-1 countdown.
• Your hop recording rises with the combo and comes back down.
• Recordings stay on your phone. They are never uploaded.

RANKING
• The weekly board is split into six ranks, Spark through Zenith.
• It opens with a hundred rows and Show more adds more.
• Your rank shows even with no connection.

CHARACTERS
• Seven new orbs: Moon, Atom, Nova, Planet, Bolt, Droplet, Ghost.
• Past 620 stars there was nothing left to earn. Thresholds now run to the
  last star, and no gap is wider than 90.

AUDIO AND HAPTICS
• The hop no longer tops out on a long combo — it climbs and comes back down.
• Losing a life has its own sound.
• Dying in endless mode played two sounds over each other.
• Haptics work again after the app has been backgrounded.
• Sounds cut each other off during fast streaks. Fixed.

TUTORIAL
• It now covers that there's no limit on hops, that yellow stars unlock
  characters, and what the arcs turning green to red actually do.
• The first bonus round explains itself.
• Level 10 announces that Endless and Speed Run are open.

SCREENS
• Personalize, Premium and Settings are three separate screens now.
• Characters, backgrounds and your own sounds live together.
• A feedback box in Settings.
• A short note when there's no connection.

LOOK
• Rings, background and orb pulled to neutral grey. The only saturated colour
  is the hazard red.
• Gate, hazard and star colours are the same in every theme.
• New logo and app icon.
• The Flame character is actually a flame now.

GAMEPLAY
• Hazard arcs don't burn on the first lap. The green cover melts away to show
  when the arc goes live.
• 257 levels, 806 stars.
• Characters aren't bought any more. They unlock at star thresholds.
• Colorblind mode.
• Premium gets one extra life per endless run.
• Restart button in endless mode.
• Past ring 20, every twelfth ring in Endless carries a heart sitting on it.
  Three lives at most.
• In Speed Run the gate stays shut until every star is collected.
• A field for premium codes.
• Leaving a tip now includes premium.

FIXES
• The weekly board showed your all-time record instead of this week's.
• Turning music off was forgotten after a relaunch.
• The logo orb on the main menu drifted downwards over time.
• No loading indicator during a purchase.
• An orb thrown into empty space in endless mode died too late.
• The level didn't end while you waited on an open gate.
• A countdown frozen at 0 on levels with no time limit.

---

## ESPAÑOL

### Texto promocional (170)
Graba el salto con tu propia voz: sube de tono con tu combo y luego vuelve a
bajar. 257 niveles, 806 estrellas y 22 personajes que se desbloquean solos.

### Palabras clave (100)
orbita,anillo,un toque,reflejos,ritmo,arcade,minimal,esfera,habilidad,infinito,clasificacion

### Descripción
Una esfera gira alrededor de su anillo. Tú solo eliges cuándo soltarla. Esa es
toda la regla; lo demás es cuestión de ritmo.

**DE ANILLO A ANILLO**
Toca y la esfera sale disparada en tangente. Si aciertas el momento, se agarra
al siguiente anillo. Si sueltas antes de tiempo, te vas al vacío.

**NO TOQUES EL ROJO**
Sobre los anillos giran arcos de peligro. Pero no queman en la primera vuelta:
una capa verde cubre el arco y se consume por ambos extremos mientras giras.
En cuanto se acaba el verde, el arco se arma. La cuenta atrás no está en otro
indicador: está en el propio arco.

**LA MELODÍA LA TOCAS TÚ**
Cada salto limpio hace sonar la siguiente nota. La escala sube, gira arriba y
vuelve a bajar por el mismo camino: una racha larga es una melodía que has
compuesto sin darte cuenta. Los jugadores premium pueden sustituir esos sonidos
por sus propias grabaciones, y tu "hop" también sube y baja con el combo.

**NO TODOS LOS NIVELES SON IGUALES**
En los niveles cronometrados hay que llegar a la puerta a tiempo. En los de
recolección, la puerta permanece cerrada hasta que recojas todas las luces del
mapa. Algunos niveles guardan una única estrella gigante: vale cuatro, pero
tendrás que salirte de tu trayectoria para alcanzarla. Cada seis niveles llega
una ronda de bonus: sin puerta, a recoger hasta que se acabe el tiempo.

**REÚNE ESTRELLAS, DESBLOQUEA PERSONAJES**
257 niveles, 806 estrellas, 22 personajes. Las estrellas nunca se gastan: al
acumularlas vas cruzando metas, y en cada meta se desbloquea una esfera nueva
por sí sola. Las bloqueadas no se ven; solo sabes cuánto falta.

**INFINITO, CONTRARRELOJ Y TABLA SEMANAL**
En el modo infinito, cuanto más subes, más pequeños y rápidos son los anillos.
En contrarreloj cuenta lo rápido que superas los diez primeros niveles. Ambos
entran en la tabla semanal, dividida en seis rangos: Chispa, Brasa, Faro,
Púlsar, Cuásar y Cénit. La tabla se reinicia cada lunes, y quien termine entre
los tres primeros gana estrellas y la esfera de campeón, la única que solo
puede ganarse.

**ACCESIBILIDAD**
El modo daltónico cambia los colores del juego por una paleta que se distingue
con cualquier tipo de daltonismo y marca los peligros con muescas además del
color. Diez fondos y 22 personajes.

Los anuncios son opcionales y nunca interrumpen una partida. Se puede jugar sin
conexión. Ninguna compra facilita el juego: en Orbeon no hay pay-to-win.

### Novedades (2.0)
Lo más importante esta vez: los jugadores premium pueden sustituir los sonidos
del juego por su propia voz.

TUS PROPIOS SONIDOS (PREMIUM)
• Graba el salto, la estrella, la vida perdida, la muerte y el nivel completado.
• La grabación empieza tras una cuenta atrás de 3-2-1.
• Tu grabación del salto sube con el combo y luego vuelve a bajar.
• Las grabaciones se quedan en tu teléfono. Nunca se suben a ningún sitio.

CLASIFICACIÓN
• La tabla semanal se divide en seis rangos, de Chispa a Cénit.
• Se abre con cien filas y "Mostrar más" añade el resto.
• Tu rango se ve también sin conexión.

PERSONAJES
• Siete esferas nuevas: Luna, Átomo, Nova, Planeta, Rayo, Gota y Fantasma.
• Pasadas las 620 estrellas ya no había nada que conseguir. Ahora hay metas
  hasta la última estrella y ningún hueco pasa de 90.

SONIDO Y VIBRACIÓN
• El salto ya no se estanca en combos largos: sube y vuelve a bajar.
• Perder una vida tiene su propio sonido.
• Al morir en el modo infinito sonaban dos efectos a la vez.
• La vibración vuelve a funcionar tras dejar la app en segundo plano.
• Los sonidos se cortaban entre sí en las rachas rápidas. Arreglado.

TUTORIAL
• Ahora explica que no hay límite de saltos, que las estrellas amarillas
  desbloquean personajes y qué hacen los arcos que pasan de verde a rojo.
• La primera ronda de bonus se explica sola.
• El nivel 10 anuncia que se abren el modo infinito y contrarreloj.

PANTALLAS
• Personalizar, Premium y Ajustes son tres pantallas separadas.
• Personajes, fondos y tus propios sonidos están juntos.
• Caja de sugerencias en Ajustes.
• Un aviso corto cuando no hay conexión.

ASPECTO
• Anillos, fondo y esfera en gris neutro. El único color saturado es el rojo
  del peligro.
• Los colores de puerta, peligro y estrella son iguales en todos los temas.
• Nuevo logotipo e icono.
• El personaje Llama es ahora una llama de verdad.

JUGABILIDAD
• Los arcos de peligro no queman en la primera vuelta. La capa verde se
  consume y muestra cuándo se arma el arco.
• 257 niveles, 806 estrellas.
• Los personajes ya no se compran. Se desbloquean al alcanzar metas.
• Modo daltónico.
• Premium incluye una vida extra en cada partida infinita.
• Botón de reinicio en el modo infinito.
• Pasado el anillo 20, cada doce anillos del modo infinito lleva un corazón
  encima. Tres vidas como máximo.
• En Contrarreloj la puerta no se abre sin recoger todas las estrellas.
• Campo para códigos premium.
• Dejar una propina ahora incluye premium.

CORRECCIONES
• La tabla semanal mostraba tu récord histórico en vez del de la semana.
• Al reabrir la app se olvidaba que habías apagado la música.
• La esfera del logotipo del menú se iba desplazando hacia abajo.
• No había indicador de carga durante una compra.
• En el modo infinito, la esfera lanzada al vacío tardaba en morir.
• El nivel no terminaba mientras esperabas sobre una puerta abierta.
• Aparecía una cuenta atrás congelada en 0 en niveles sin tiempo.
