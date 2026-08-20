# Orbeon 1.7 — mağaza metinleri

Diller: **TR · EN · ES**. Karakter sınırları App Store'a göre:
promosyon metni 170, açıklama 4000, yenilikler 4000, anahtar kelimeler 100.

Ekran görüntüleri: `appstore-{dil}-{1..5}-{sahne}.png` (1320×2868) ve
`6.5-inch/` (1242×2688). Beşi de `build_shots.py` ile üretiliyor —
metin değişince yeniden çalıştır, elle düzenleme.

---

## TÜRKÇE

### Promosyon metni (170)
Tehlike yayı ilk turda yakmaz — geri sayım yayın üstünde eriyor. 257 bölüm,
806 yıldız ve yıldız topladıkça kendiliğinden açılan karakterler.

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

**HER BÖLÜM AYNI DEĞİL**
Süreli bölümlerde kapıya yetişmen gerekir. Topla-bitir bölümlerinde kapı,
haritadaki bütün ışıkları toplayana kadar kilitli kalır. Bazı bölümlerde tek
bir dev yıldız vardır: dört eder, ama hattından sapmayı göze almalısın.

**YILDIZ TOPLA, KARAKTER AÇ**
257 bölüm, 806 yıldız. Yıldızlar harcanmaz — biriktikçe eşikleri geçersin ve
her eşikte yeni bir küre kendiliğinden açılır. Kilitli olanları göremezsin,
yalnızca ne kadar kaldığını bilirsin.

**SONSUZ MOD VE HAFTALIK SIRALAMA**
Yukarı çıktıkça halkalar küçülür ve hızlanır. Skorun haftalık tabloya yazılır,
tablo her pazartesi sıfırlanır. Haftayı ilk üçte bitirenler yıldız ve yalnızca
kazanılabilen şampiyon küresini alır.

**ERİŞİLEBİLİRLİK**
Renk körlüğü modu: oynanışı belirleyen renkler her renk körlüğü türünde
ayrışan bir palete geçer, tehlike yayları renge ek olarak çentiklerle
işaretlenir. On arka plan teması, on beş karakter.

Reklamlar isteğe bağlıdır ve oynanışa karışmaz. Hiçbir satın alma oyunu
kolaylaştırmaz — Orbeon'da pay-to-win yoktur.

### Yenilikler (1.7)
Bu sürüm baştan aşağı bir görünüm yenilemesi.

• Yeni görsel dil. Halkalar, zemin ve küre nötr griye çekildi; ekranın en
  parlak şeyi artık hedef kapısı, tek doygun rengi de tehlike kırmızısı.
  Parıltılar kalktı — uzun oturumlarda göz çok daha az yoruluyor.
• Kapı, tehlike ve yıldız renkleri artık bütün temalarda aynı. Tema
  değiştirmek oyunun dilini değiştirmiyor, yalnızca zeminin tonunu.
• Yeni logo ve uygulama ikonu: bir halka, tek kırmızı yay ve çemberin
  üstündeki küre. Açılış ekranı da bu işaretle yeniden kuruldu.
• Tehlike yayları ilk turda yakmıyor ve bunu ÖNCEDEN gösteriyor. Yayın
  üstündeki yeşil kaplama tur boyunca iki ucundan eriyor.
• Kampanya 257 bölüme, toplam 806 yıldıza çıktı.
• Karakterler artık satın alınmıyor: yıldız eşiği geçilince kendiliğinden
  açılıyor ve açıldığı anda kutlama ekranı çıkıyor.
• Renk körlüğü modu eklendi.
• Premium oyunculara sonsuz modda tur başına bir can hakkı.
• Hız turunda kapı, yıldızların hepsi toplanmadan açılmıyor.
• Sonsuz modda boşluğa atılan küre artık gecikmeden ölüyor; 0 skor
  sıralamaya yazılmıyor.
• Düzeltmeler: açık kapının üstünde beklerken bölüm bitmiyordu; süresiz
  bölümlerde 0'da donmuş bir sayaç görünüyordu.

---

## ENGLISH

### Promotional text (170)
The hazard arc won't burn you on the first lap — the countdown melts away on
the arc itself. 257 levels, 806 stars, characters that unlock as you collect.

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

**NOT EVERY LEVEL IS THE SAME**
Timed levels want you at the gate before the clock runs out. Collect levels
keep the gate locked until you've swept every light off the map. Some levels
hold a single giant star: worth four, but you have to leave your line to
reach it.

**COLLECT STARS, UNLOCK CHARACTERS**
257 levels, 806 stars. Stars are never spent — as they add up you cross
thresholds, and at every threshold a new orb unlocks on its own. Locked ones
stay hidden; you only know how far away they are.

**ENDLESS MODE AND THE WEEKLY BOARD**
The higher you climb, the smaller and faster the rings get. Your score goes on
the weekly board, which resets every Monday. Finish the week in the top three
and you win stars plus the champion orb — the one orb that can only be won.

**ACCESSIBILITY**
Colorblind mode switches the gameplay colours to a palette that stays distinct
for every kind of colour blindness, and marks hazards with notches as well as
colour. Ten background themes, fifteen characters.

Ads are optional and never interrupt a run. No purchase makes the game easier
— there is no pay-to-win in Orbeon.

### What's New (1.7)
This release is a full visual overhaul.

• A new visual language. Rings, background and orb are pulled to neutral grey;
  the brightest thing on screen is now the target gate, and the only saturated
  colour is the hazard red. The glow is gone — far easier on the eyes over a
  long session.
• Gate, hazard and star colours are now identical across every theme. Changing
  theme no longer changes the language of the game, only the tone of the
  background.
• New logo and app icon: a ring, one red arc, and the orb sitting on the
  circle. The splash screen was rebuilt around the same mark.
• Hazard arcs don't burn on the first lap, and they show it IN ADVANCE. The
  green cover on the arc melts away from both ends as the lap runs down.
• The campaign grew to 257 levels and 806 stars.
• Characters are no longer bought. They unlock on their own when you cross a
  star threshold, with a reveal screen the moment it happens.
• Colorblind mode added.
• Premium players get one extra life per endless run.
• In Speed Run the gate no longer opens before every star is collected.
• An orb thrown into empty space in endless mode now dies without the delay,
  and a score of 0 is no longer written to the leaderboard.
• Fixes: the level didn't end while you waited on an open gate; a countdown
  frozen at 0 appeared on levels that have no time limit.

---

## ESPAÑOL

### Texto promocional (170)
El arco de peligro no quema en la primera vuelta: la cuenta atrás se consume
en el propio arco. 257 niveles, 806 estrellas y personajes que se desbloquean.

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

**NO TODOS LOS NIVELES SON IGUALES**
En los niveles cronometrados hay que llegar a la puerta a tiempo. En los de
recolección, la puerta permanece cerrada hasta que recojas todas las luces del
mapa. Algunos niveles guardan una única estrella gigante: vale cuatro, pero
tendrás que salirte de tu trayectoria para alcanzarla.

**REÚNE ESTRELLAS, DESBLOQUEA PERSONAJES**
257 niveles, 806 estrellas. Las estrellas nunca se gastan: al acumularlas vas
cruzando metas, y en cada meta se desbloquea una esfera nueva por sí sola. Las
bloqueadas no se ven; solo sabes cuánto falta para conseguirlas.

**MODO INFINITO Y TABLA SEMANAL**
Cuanto más subes, más pequeños y rápidos son los anillos. Tu puntuación entra
en la tabla semanal, que se reinicia cada lunes. Quien termine la semana entre
los tres primeros gana estrellas y la esfera de campeón, la única que solo
puede ganarse.

**ACCESIBILIDAD**
El modo daltónico cambia los colores del juego por una paleta que se distingue
con cualquier tipo de daltonismo y marca los peligros con muescas además del
color. Diez fondos y quince personajes.

Los anuncios son opcionales y nunca interrumpen una partida. Ninguna compra
facilita el juego: en Orbeon no hay pay-to-win.

### Novedades (1.7)
Esta versión renueva por completo el aspecto del juego.

• Nuevo lenguaje visual. Anillos, fondo y esfera pasan a un gris neutro; lo más
  luminoso de la pantalla es ahora la puerta objetivo y el único color saturado
  es el rojo del peligro. Se han eliminado los brillos: la vista se cansa mucho
  menos en partidas largas.
• Los colores de puerta, peligro y estrella son idénticos en todos los temas.
  Cambiar de tema ya no cambia el lenguaje del juego, solo el tono del fondo.
• Nuevo logotipo e icono: un anillo, un solo arco rojo y la esfera apoyada en
  el círculo. La pantalla de inicio se ha rehecho con esa misma marca.
• Los arcos de peligro no queman en la primera vuelta, y lo muestran DE
  ANTEMANO: la capa verde se consume por ambos extremos.
• La campaña crece hasta 257 niveles y 806 estrellas.
• Los personajes ya no se compran: se desbloquean solos al cruzar una meta de
  estrellas, con una pantalla de celebración en ese mismo momento.
• Añadido el modo daltónico.
• Los jugadores premium tienen una vida extra por partida en el modo infinito.
• En Contrarreloj la puerta ya no se abre sin recoger todas las estrellas.
• En el modo infinito, la esfera lanzada al vacío ya no tarda en morir, y una
  puntuación de 0 no se registra en la clasificación.
• Correcciones: el nivel no terminaba mientras esperabas sobre una puerta
  abierta; aparecía una cuenta atrás congelada en 0 en niveles sin tiempo.
