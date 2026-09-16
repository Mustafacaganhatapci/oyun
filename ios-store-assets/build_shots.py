#!/usr/bin/env python3
"""App Store ekran görüntülerini üretir — 6 sahne × 3 dil × 2 boy.

Sahneler oyunun GERÇEK çizim kurallarıyla kurulur: mat palet, parıltısız
halka çizgisi, kapının dönen kesikli dış çemberi, yeşilden kırmızıya eriyen
tehlike yayı, altın lümen, kürenin sönümlenen izi. Metin katmanı dilden dile
değiştiği için işaretleme elle tekrarlanmıyor, buradan üretiliyor.

Palet oyunun `Theme.nebula` değerleriyle birebir aynı; "tek vurgu" dilinde
anlam taşıyan üç renk (kapı ≈ beyaz, tehlike kırmızı, yıldız altın) bütün
temalarda sabit olduğu için mağaza görselleri de oyunla aynı şeyi gösteriyor.

Kullanım:
    python3 build_shots.py            # shots.html üretir
    python3 build_shots.py --render   # + PNG'leri yazar (Playwright + Pillow ister)

Render iki boyu birden yazıyor: 6.9" (1320×2868) bu klasöre, 6.5"
(1242×2688) `6.5-inch/` altına. İkincisi birincisinden küçültülüyor —
çizimin tamamı vektör olduğu için kayıp yok.
"""
import math
import pathlib
import sys

W, H = 1320, 2868

# Theme.nebula — mat palet
BG_TOP    = "#0C0C0F"
BG_BOTTOM = "#18161C"
RING      = "#807F8A"
GATE      = "#D3F3EC"
ORB       = "#F0F1F3"
HAZARD    = "#D1495B"
HAZ_SAFE  = "#537658"
LUMEN     = "#B59450"
ACCENT    = "#746E87"


def star_path(cx, cy, outer, inner, points=5, rot=-90.0):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180.0 / points)
        pts.append(f"{cx + math.cos(a) * r:.1f} {cy + math.sin(a) * r:.1f}")
    return "M " + " L ".join(pts) + " Z"


def arc_path(cx, cy, r, a0, a1):
    x0, y0 = cx + math.cos(math.radians(a0)) * r, cy + math.sin(math.radians(a0)) * r
    x1, y1 = cx + math.cos(math.radians(a1)) * r, cy + math.sin(math.radians(a1)) * r
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}"


def ring(cx, cy, r, color=RING, w=9):
    """Mat halka: parıltı yok, tek çizgi."""
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{color}" stroke-width="{w}"'
            f' fill="none"/>')


def gate(cx, cy, r, locked=False):
    """Hedef kapısı — ekranın en parlak şeyi. Kilitliyse sönük ve asma kilitli."""
    dim = ".34" if locked else "1"
    out = (f'<g opacity="{dim}">'
           f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{GATE}" stroke-width="26"'
           f' fill="none" opacity=".12"/>'
           f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{GATE}" stroke-width="9" fill="none"/>'
           f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{GATE}" opacity=".05"/>'
           f'<circle cx="{cx}" cy="{cy}" r="{r + 30}" stroke="{GATE}" stroke-width="5"'
           f' fill="none" stroke-dasharray="20 26" opacity=".55"/></g>')
    if locked:
        out += (f'<g fill="none" stroke="{GATE}" stroke-width="9" opacity=".75">'
                f'<rect x="{cx - 40}" y="{cy - 4}" width="80" height="62" rx="13"'
                f' fill="{GATE}" opacity=".30" stroke="none"/>'
                f'<path d="M {cx - 24} {cy - 4} v -24 a 24 24 0 0 1 48 0 v 24"/></g>')
    return out


def orb(cx, cy, r=22):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r * 1.9:.0f}" fill="{ORB}" opacity=".10"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{ORB}"/>')


def trail(x0, y0, x1, y1):
    out = ""
    for i, (rr, op) in enumerate([(7, .12), (10, .20), (13, .30), (17, .42)]):
        t = (i + 1) / 5
        out += (f'<circle cx="{x0 + (x1 - x0) * t:.0f}" cy="{y0 + (y1 - y0) * t:.0f}"'
                f' r="{rr}" fill="{ACCENT}" opacity="{op}"/>')
    return out


def lumen(cx, cy):
    return (f'<circle cx="{cx}" cy="{cy}" r="30" fill="{LUMEN}" opacity=".14"/>'
            f'<circle cx="{cx}" cy="{cy}" r="17" fill="{LUMEN}"/>')


def grand(cx, cy):
    return (f'<circle cx="{cx}" cy="{cy}" r="66" fill="{LUMEN}" opacity=".13"/>'
            f'<path d="{star_path(cx, cy, 52, 22)}" fill="{LUMEN}"/>')


def hazard(cx, cy, r, a0, a1, safe=1.0):
    """Tehlike yayı. `safe` = yeşil kaplamanın kalan oranı (1 = hiç
    dokunulmamış, 0 = silahlı). Kırmızı ile yeşil ÜST ÜSTE BİNMEZ, yayı
    bölüşürler — oyundaki çizimin aynısı."""
    span = a1 - a0
    mid = (a0 + a1) / 2
    half = span * safe / 2
    out = ""
    if safe < 0.999:
        for s0, s1 in ((a0, mid - half), (mid + half, a1)):
            if s1 - s0 <= 0.2:
                continue
            d = arc_path(cx, cy, r, s0, s1)
            out += (f'<path d="{d}" stroke="{HAZARD}" stroke-width="30" stroke-linecap="round"'
                    f' fill="none" opacity=".16"/>'
                    f'<path d="{d}" stroke="{HAZARD}" stroke-width="20" stroke-linecap="round"'
                    f' fill="none"/>')
    if safe > 0.001:
        d = arc_path(cx, cy, r, mid - half, mid + half)
        out += (f'<path d="{d}" stroke="{HAZ_SAFE}" stroke-width="20" stroke-linecap="round"'
                f' fill="none"/>')
    return out


# ---------------------------------------------------------------- karakterler

def orb_glyph(cx, cy, kind, locked=False):
    """Karakter önizlemesi — mağaza sahnesindeki küçük madalyonlar."""
    body = ""
    if kind == "classic":
        body = f'<circle cx="{cx}" cy="{cy}" r="26" fill="{ORB}"/>'
    elif kind == "star":
        body = f'<path d="{star_path(cx, cy, 30, 13)}" fill="{LUMEN}"/>'
    elif kind == "ring":
        body = f'<circle cx="{cx}" cy="{cy}" r="25" stroke="{ORB}" stroke-width="9" fill="none"/>'
    elif kind == "bubble":
        body = (f'<circle cx="{cx}" cy="{cy}" r="27" stroke="{GATE}" stroke-width="5"'
                f' fill="{GATE}" fill-opacity=".12"/>'
                f'<circle cx="{cx - 9}" cy="{cy - 10}" r="6" fill="#fff" opacity=".8"/>')
    elif kind == "diamond":
        body = (f'<path d="M {cx} {cy-30} L {cx+26} {cy} L {cx} {cy+30} L {cx-26} {cy} Z"'
                f' fill="{ACCENT}"/>')
    elif kind == "comet":
        body = (f'<path d="M {cx-34} {cy} L {cx+6} {cy}" stroke="{ACCENT}" stroke-width="12"'
                f' stroke-linecap="round" opacity=".55"/>'
                f'<circle cx="{cx+14}" cy="{cy}" r="17" fill="{ORB}"/>')
    frame = (f'<circle cx="{cx}" cy="{cy}" r="58" fill="#000" fill-opacity=".22"'
             f' stroke="{RING}" stroke-width="3" stroke-opacity=".5"/>')
    if locked:
        # Kilitli karakter BULANIK ve adsız: ne kazanacağını merak etsin
        return (frame + f'<g filter="url(#blur)" opacity=".55">{body}</g>'
                f'<g fill="none" stroke="#fff" stroke-width="7" opacity=".8">'
                f'<rect x="{cx-19}" y="{cy-2}" width="38" height="30" rx="7"'
                f' fill="#fff" fill-opacity=".85" stroke="none"/>'
                f'<path d="M {cx-11} {cy-2} v -11 a 11 11 0 0 1 22 0 v 11"/></g>')
    return frame + body


DEFS = ('<defs><filter id="blur" x="-70%" y="-70%" width="240%" height="240%">'
        '<feGaussianBlur stdDeviation="11"/></filter></defs>')


# --------------------------------------------------------------------- sahneler

def scene_core():
    s = ring(880, 2760, 150) + ring(900, 2380, 150) + ring(400, 2030, 134)
    s += ring(950, 1670, 140) + ring(380, 1310, 132)
    s += gate(900, 940, 145)
    s += trail(400, 2030, 682, 1846) + orb(682, 1846)
    s += lumen(790, 1760) + lumen(640, 1490) + lumen(1140, 2160)
    return DEFS + s


def scene_hazard():
    """Yeni mekanik: tehlike yayı ilk turda yakmaz, yeşil iki ucundan erir."""
    s = ring(880, 2760, 140)
    s += ring(400, 2380, 150) + hazard(400, 2380, 150, -150, -30, safe=1.0)
    s += orb(400, 2230)
    s += ring(950, 1960, 140) + hazard(950, 1960, 140, -140, -20, safe=0.45)
    s += ring(420, 1560, 132) + hazard(420, 1560, 132, 140, 250, safe=0.0)
    s += ring(920, 1180, 138) + hazard(920, 1180, 138, -60, 40, safe=1.0)
    s += lumen(700, 2160) + lumen(680, 1770) + lumen(1120, 1420)
    return DEFS + s


def scene_collect():
    s = gate(880, 1010, 150, locked=True)
    s += ring(870, 2770, 145) + ring(900, 2420, 150) + ring(380, 2090, 145)
    s += ring(930, 1740, 132) + ring(380, 1390, 138)
    s += trail(380, 2090, 704, 1890) + orb(704, 1890)
    s += lumen(620, 1620) + lumen(1130, 2130) + lumen(650, 1230)
    return DEFS + s


def scene_characters():
    """Karakterler yıldız topladıkça kendiliğinden açılır."""
    # Az önce açılan karakter büyük, "sunuluyor" gibi
    s = (f'<circle cx="660" cy="1360" r="250" fill="{LUMEN}" opacity=".07"/>'
         f'<circle cx="660" cy="1360" r="190" stroke="{LUMEN}" stroke-width="4"'
         f' stroke-dasharray="14 22" fill="none" opacity=".55"/>')
    s += f'<path d="{star_path(660, 1360, 126, 54)}" fill="{LUMEN}"/>'
    # Altında koleksiyon: açılanlar net, kilitliler bulanık
    xs = [285, 525, 795, 1035]
    for x, k in zip(xs, ("classic", "star", "ring", "bubble")):
        s += orb_glyph(x, 2080, k, False)
    for x, k in zip(xs, ("diamond", "comet", "star", "ring")):
        s += orb_glyph(x, 2300, k, True)
    return DEFS + s


def scene_endless():
    """Sonsuz mod: kamera yukarı bakar, halkalar yukarı doğru incelir."""
    s = ring(880, 2780, 150) + ring(860, 2440, 142) + ring(400, 2120, 128)
    s += ring(900, 1820, 118)
    s += ring(420, 1530, 108) + hazard(420, 1530, 108, -150, -40, safe=1.0)
    s += ring(880, 1280, 98) + ring(470, 1060, 88) + ring(830, 880, 78)
    s += trail(400, 2120, 690, 1960) + orb(690, 1960)
    s += lumen(700, 1690) + lumen(640, 1390)
    return DEFS + s


def heart(cx, cy, r=30):
    """Halkanın üstünde duran can. Oyundaki çizimin aynısı."""
    return (f'<path d="M {cx} {cy + r * 0.78} '
            f'C {cx - r * 1.5} {cy - r * 0.25} {cx - r * 0.62} {cy - r * 1.15} {cx} {cy - r * 0.32} '
            f'C {cx + r * 0.62} {cy - r * 1.15} {cx + r * 1.5} {cy - r * 0.25} {cx} {cy + r * 0.78} Z" '
            f'fill="{HAZARD}"/>')


def scene_lives():
    """2.0: sonsuz modda halkanın ÜSTÜNDE duran canlar — 12, 20, 28 …"""
    s = ring(880, 2780, 148) + ring(400, 2450, 138)
    s += ring(900, 2130, 128) + heart(900, 2002)
    s += ring(420, 1830, 118)
    s += ring(880, 1540, 108) + hazard(880, 1540, 108, 150, 250, safe=1.0)
    s += ring(450, 1290, 96) + heart(450, 1194, 26)
    s += ring(860, 1080, 84) + ring(500, 900, 74)
    s += trail(400, 2450, 676, 2300) + orb(676, 2300)
    s += lumen(660, 2020) + lumen(700, 1660)
    return DEFS + s


def hud(level, pips_on, total=3):
    pips = "".join(
        f'<div class="pip{" on" if i < pips_on else ""}"></div>' for i in range(total))
    return (f'<div class="hud"><div class="hud-btn"><span></span></div>'
            f'<div class="hud-lvl">{level}</div><div class="pips">{pips}</div></div>')


SCENES = [
    ("core",       scene_core,       lambda: hud("14", 2)),
    ("hazard",     scene_hazard,     lambda: hud("74", 1)),
    ("collect",    scene_collect,    lambda: hud("88", 1)),
    ("characters", scene_characters, lambda: ""),
    ("endless",    scene_endless,    lambda: ""),
    ("lives",      scene_lives,      lambda: ""),
]

COPY = {
 "tr": [
  ("Küre halkada döner.<br>Sen <em>bırakırsın</em>.",
   "Erken dokunursan boşluğa gider, geç kalırsan bir<br>tur daha döner. Oyunun tamamı bu tek karar."),
  ("<span class='safe'>Yeşil</span> yay erir.<br>Kırmızısı <em>yakar</em>.",
   "Bir halkada ne kadar beklediğini ekranın köşesinde<br>değil, halkanın kendi üstünde görüyorsun."),
  ("Kapı <span class='gate'>sönükse</span><br>daha <em>bitmedi</em>.",
   "Yıldızları toplamadan kapıya konmak hiçbir şey<br>yapmıyor. Bu bölümlerde ölürsen de baştan başlıyorsun."),
  ("Her eşikte<br>yeni bir <em>küre</em>.",
   "257 bölüm, 806 yıldız. Açtığın küreyle oynamaya<br>devam ediyorsun; eskisine dönmek de serbest."),
  ("Sonsuz modda<br>bölüm <em>yok</em>.",
   "Halkalar yükseldikçe hızlanıyor ve aralıkları açılıyor.<br>Nerede bıraktığın haftalık sıralamaya yazılıyor."),
  ("12. halkadan sonra<br>oyun <em>can</em> veriyor.",
   "Sekiz halkada bir düşüyor, elinde en fazla üç tane<br>birikiyor. Canın varken ölmek turu bitirmiyor."),
 ],
 "en": [
  ("The orb circles.<br>You <em>let go</em>.",
   "Too early and it sails past the next ring, too late<br>and you go round again. The game is that one call."),
  ("<span class='safe'>Green</span> arc melts.<br>The red one <em>burns</em>.",
   "How long you've sat on a ring isn't in a corner of<br>the screen. It's drawn on the ring you're sitting on."),
  ("A dim gate<br>means <em>not yet</em>.",
   "Landing on it before you've taken the stars does<br>nothing. Die in these levels and you start over."),
  ("A new <em>orb</em> at<br>every milestone.",
   "257 levels, 806 stars. Play on with whatever you've<br>just unlocked, or go back to one you liked."),
  ("Endless has<br>no <em>levels</em>.",
   "The higher you climb, the faster the rings turn<br>and the wider they sit. Your best goes on the board."),
  ("Past ring twelve,<br><em>lives</em> start coming.",
   "One every eight rings, three in hand at most. With<br>a life left, dying doesn't end the run."),
 ],
 "es": [
  ("La esfera gira.<br>Tú la <em>sueltas</em>.",
   "Si sueltas pronto pasa de largo; si tardas, das otra<br>vuelta. Todo el juego es esa única decisión."),
  ("El arco <span class='safe'>verde</span> se gasta.<br>El rojo <em>quema</em>.",
   "Cuánto llevas sobre un anillo no está en una esquina<br>de la pantalla: está dibujado en el propio anillo."),
  ("Puerta <span class='gate'>apagada</span>,<br>aún <em>no</em>.",
   "Posarse en ella sin haber cogido las estrellas no<br>hace nada. Y si mueres aquí, el nivel vuelve a empezar."),
  ("Una <em>esfera</em> nueva<br>en cada meta.",
   "257 niveles, 806 estrellas. Sigue con la que acabas<br>de abrir, o vuelve a la que más te gustaba."),
  ("El infinito<br>no tiene <em>niveles</em>.",
   "Cuanto más alto llegas, más rápido giran los anillos<br>y más separados están. Tu mejor marca va a la tabla."),
  ("Del anillo doce<br>llegan <em>vidas</em>.",
   "Una cada ocho anillos, tres como máximo. Con una<br>vida, morir no acaba la partida."),
 ],
}

CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#000; font-family:"Inter","Inter Display",Helvetica,Arial,sans-serif; }}
.shot {{ position:relative; width:{W}px; height:{H}px; overflow:hidden;
  background:linear-gradient(180deg,{BG_TOP} 0%,{BG_BOTTOM} 100%); }}

/* Ortam ışığı. Sahne düz siyahın üstünde duruyordu ve başlıkla ilk halka
   arasındaki boşluk delik gibi görünüyordu; iki yumuşak havuz o bandı
   ışıkla dolduruyor. Renkler oyunun kendi vurgusu — uydurma bir mor değil. */
.glow {{ position:absolute; border-radius:50%; pointer-events:none; }}
.glow-a {{ width:1500px; height:1500px; left:-360px; top:420px;
  background:radial-gradient(circle,{ACCENT}2E 0%,{ACCENT}00 62%); }}
.glow-b {{ width:1100px; height:1100px; right:-320px; top:1500px;
  background:radial-gradient(circle,{LUMEN}22 0%,{LUMEN}00 64%); }}

/* Yazının arkasındaki perde: sahne yukarıda da devam etsin ama başlık
   okunaklı kalsın. Kesik bir kenar yok, aşağı doğru eriyor. */
.scrim {{ position:absolute; left:0; right:0; top:0; height:1180px; z-index:4;
  background:linear-gradient(180deg,rgba(8,8,11,.94) 0%,rgba(8,8,11,.86) 42%,
    rgba(8,8,11,.42) 76%,rgba(8,8,11,0) 100%); }}
/* Altta da aynısı: halkalar kadrajın kenarında sert kesilmesin */
.fade {{ position:absolute; left:0; right:0; bottom:0; height:620px; z-index:4;
  background:linear-gradient(0deg,{BG_BOTTOM} 0%,{BG_BOTTOM}F2 26%,rgba(24,22,28,0) 100%); }}

.star {{ position:absolute; border-radius:50%; background:#fff; }}
.copy {{ position:absolute; left:0; right:0; top:224px; text-align:center; padding:0 90px; z-index:5; }}
.head {{ font-size:104px; font-weight:300; letter-spacing:-2px; line-height:1.08; color:#fff; }}
.head em {{ font-style:normal; font-weight:600; color:#fff; }}
.head .gate {{ color:{GATE}; }}
.head .safe {{ color:#6E9C74; }}
.sub {{ margin-top:34px; font-size:40px; font-weight:400; line-height:1.4;
  color:rgba(255,255,255,0.52); }}

/* Etiket çipi — sayfanın hangi şeyi anlattığını tek kelimeyle söylüyor ve
   başlığın altındaki boşluğu bir şeye bağlıyor. */
.chip {{ display:inline-block; margin-top:44px; padding:16px 34px; border-radius:999px;
  font-size:32px; font-weight:600; letter-spacing:2px;
  color:rgba(255,255,255,.82); background:rgba(255,255,255,.07);
  border:2px solid rgba(255,255,255,.14); }}
.chip.new {{ color:{HAZARD}; background:{HAZARD}1A; border-color:{HAZARD}55; }}

.hud {{ position:absolute; left:0; right:0; top:70px; display:flex; align-items:center;
  justify-content:space-between; padding:0 78px; z-index:6; }}
.hud-btn {{ width:84px; height:84px; border-radius:50%; background:rgba(255,255,255,0.10);
  display:flex; align-items:center; justify-content:center; }}
.hud-btn span {{ display:block; width:8px; height:30px; background:rgba(255,255,255,0.8);
  box-shadow:16px 0 0 rgba(255,255,255,0.8); margin-right:16px; }}
.hud-lvl {{ font-size:38px; font-weight:500; color:rgba(255,255,255,0.7); letter-spacing:3px; }}
.pips {{ display:flex; gap:14px; }}
.pip {{ width:24px; height:24px; border-radius:50%; background:rgba(255,255,255,0.18); }}
.pip.on {{ background:{LUMEN}; }}
.hud-score {{ font-size:64px; font-weight:600; color:#fff; }}
.goal {{ position:absolute; left:0; right:0; top:2500px; text-align:center; z-index:6;
  font-size:36px; font-weight:600; color:{LUMEN}; }}

/* Marka kilidi: halka O'nun yerinde — açılış ekranının bitiş karesi.
   Yalnızca ilk görselde, altta. */
.brand {{ position:absolute; left:0; right:0; bottom:150px; z-index:6;
  display:flex; align-items:center; justify-content:center; gap:0; }}
.brand svg {{ display:block; margin-right:14px; }}
.brand .word {{ font-size:66px; font-weight:300; letter-spacing:22px; color:#fff;
  margin-right:-22px; }}

svg.scene {{ position:absolute; left:0; top:0; }}
"""

STARS = [(180, 820, 4, .34), (1040, 1180, 5, .40), (320, 2260, 4, .30),
         (980, 2520, 5, .34), (660, 1560, 4, .26), (240, 1300, 4, .30)]

# Etiket çipi: sayfanın konusu tek kelimeyle. Yeni olan işaretli.
# Büyük harfler ELLE yazılıyor. CSS'in `text-transform:uppercase` kuralı
# Türkçeyi bilmiyor: "Yeni" → "YENI", noktalı İ kayboluyor.
TAGS = {
 "tr": ["OYNANIŞ", "TEHLİKE", "BÖLÜMLER", "KARAKTERLER", "SONSUZ", ("YENİ", True)],
 "en": ["GAMEPLAY", "HAZARDS", "LEVELS", "CHARACTERS", "ENDLESS", ("NEW", True)],
 "es": ["JUGABILIDAD", "PELIGROS", "NIVELES", "PERSONAJES", "INFINITO", ("NUEVO", True)],
}

GOAL_COPY = {"tr": "★ Sıradaki karaktere 12 yıldız",
             "en": "★ 12 stars to the next character",
             "es": "★ 12 estrellas para el próximo personaje"}


def build():
    shots = []
    for lang in COPY:
        for i, (name, scene_fn, hud_fn) in enumerate(SCENES):
            head, sub = COPY[lang][i]
            stars = "".join(
                f'<div class="star" style="width:{s}px;height:{s}px;left:{x}px;top:{y}px;opacity:{o}"></div>'
                for (x, y, s, o) in STARS)
            extra = hud_fn()
            if name in ("endless", "lives"):
                # Sonsuz modda bölüm numarası yerine skor var
                score = "31" if name == "endless" else "24"
                extra = ('<div class="hud"><div class="hud-btn"><span></span></div>'
                         f'<div class="hud-score">{score}</div>'
                         '<div style="width:84px"></div></div>')
            elif name == "characters":
                extra = f'<div class="goal">{GOAL_COPY[lang]}</div>'

            tag = TAGS[lang][i]
            label, is_new = tag if isinstance(tag, tuple) else (tag, False)
            chip = f'<div class="chip{" new" if is_new else ""}">{label}</div>'

            # Marka kilidi yalnızca ilk görselde: bir sette imza bir kez atılır
            brand = ""
            if i == 0:
                brand = (
                    '<div class="brand">'
                    '<svg width="86" height="86" viewBox="0 0 86 86">'
                    f'<circle cx="43" cy="43" r="33" stroke="{RING}" stroke-width="4" fill="none"/>'
                    f'<path d="{arc_path(43, 43, 33, -128, -34)}" stroke="{HAZARD}"'
                    ' stroke-width="9" stroke-linecap="round" fill="none"/>'
                    f'<circle cx="20" cy="66" r="7" fill="{ORB}"/>'
                    '</svg>'
                    '<div class="word">RBEON</div></div>')

            shots.append(
                f'<div class="shot" id="{lang}{i+1}">'
                '<div class="glow glow-a"></div><div class="glow glow-b"></div>'
                f'<svg class="scene" width="{W}" height="{H}">{scene_fn()}</svg>'
                '<div class="scrim"></div><div class="fade"></div>'
                f'{stars}{extra}'
                f'<div class="copy"><div class="head">{head}</div>'
                f'<div class="sub">{sub}</div>{chip}</div>'
                f'{brand}</div>')
    return ("<!DOCTYPE html><html><head><meta charset='utf-8'><style>"
            + CSS + "</style></head><body>" + "".join(shots) + "</body></html>")


def render(html_path, out_dir):
    """Her .shot düğümünü ayrı PNG olarak yazar."""
    from playwright.sync_api import sync_playwright
    out_dir.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        # Playwright'ın beklediği "headless shell" bu ortamda yok; tam
        # Chromium kurulu, doğrudan onu başlatıyoruz.
        exe = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"
        browser = (p.chromium.launch(executable_path=exe)
                   if pathlib.Path(exe).exists() else p.chromium.launch())
        page = browser.new_page(viewport={"width": W, "height": H})
        page.goto(html_path.as_uri())
        page.wait_for_timeout(600)
        for lang in COPY:
            for i, (name, _, _) in enumerate(SCENES):
                el = page.query_selector(f"#{lang}{i+1}")
                target = out_dir / f"appstore-{lang}-{i+1}-{name}.png"
                el.screenshot(path=str(target))
                print("yazıldı:", target.name)
                downscale(target, out_dir / "6.5-inch" / target.name)
        browser.close()


# App Store iki boy istiyor: 6.9" (1320×2868) ve 6.5" (1242×2688). İkisinin
# en-boy oranı birebir aynı değil (0.4603 / 0.4620), o yüzden genişliğe göre
# küçültülüp taşan 10 piksel ALTTAN kırpılıyor — orası zaten sahnenin eridiği
# perde, kaybolan bir şey yok. Sahneyi ikinci kez, başka koordinatlarla
# çizmenin anlamı yok: çizimin tamamı vektör.
SMALL_W, SMALL_H = 1242, 2688


def downscale(src, dst):
    from PIL import Image
    dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src)
    scaled = im.resize((SMALL_W, round(im.height * SMALL_W / im.width)), Image.LANCZOS)
    scaled.crop((0, 0, SMALL_W, SMALL_H)).save(dst)


# Play Store aynı sahneleri istiyor ama başka bir ORANDA: App Store'un
# 1320×2868'i 1:2,17, Play'in kabul ettiği en uzun oran ise 9:16 (1:1,78).
# Sahneyi ikinci kez, başka koordinatlarla çizmek yerine tamamı YÜKSEKLİĞE
# göre küçültülüp yanları oyunun kendi zemin gradyanıyla dolduruluyor:
# eklenen şey siyah bant değil, sahnenin zaten üstünde durduğu zemin. Böylece
# tek bir kompozisyon iki mağazada da eksiksiz görünüyor.
PLAY_W, PLAY_H = 1080, 1920


def to_play(src, dst):
    from PIL import Image
    dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGB")
    scaled = im.resize((round(im.width * PLAY_H / im.height), PLAY_H), Image.LANCZOS)

    # Yanlar sahnenin KENDİ kenar sütunu uzatılarak dolduruluyor, düz bir
    # gradyanla değil. Sahnede vinyet ve ışık havuzları var; sabit bir zemin
    # koyulunca kenarlarda görünür bir çerçeve oluşuyordu. Kenardaki içerik
    # zaten neredeyse düz zemin olduğu için uzatma dikişsiz duruyor.
    canvas = Image.new("RGB", (PLAY_W, PLAY_H))
    left = (PLAY_W - scaled.width) // 2
    right = PLAY_W - scaled.width - left
    if left > 0:
        edge = scaled.crop((0, 0, 1, PLAY_H)).resize((left, PLAY_H))
        canvas.paste(edge, (0, 0))
    if right > 0:
        edge = scaled.crop((scaled.width - 1, 0, scaled.width, PLAY_H)).resize((right, PLAY_H))
        canvas.paste(edge, (PLAY_W - right, 0))
    canvas.paste(scaled, (left, 0))
    canvas.save(dst)


def render_play(html_path, out_dir):
    """App Store boyundan Play boyuna: aynı sahneler, 1080×1920."""
    here = pathlib.Path(__file__).parent
    out_dir.mkdir(parents=True, exist_ok=True)
    for lang in COPY:
        for i, (name, _, _) in enumerate(SCENES):
            src = here / f"appstore-{lang}-{i + 1}-{name}.png"
            if not src.exists():
                print("atlandı (önce --render):", src.name)
                continue
            dst = out_dir / f"play-{lang}-{i + 1}-{name}.png"
            to_play(src, dst)
            print("yazıldı:", dst.name)


if __name__ == "__main__":
    here = pathlib.Path(__file__).parent
    out = here / "shots.html"
    out.write_text(build(), encoding="utf-8")
    print("yazıldı:", out)
    if "--render" in sys.argv:
        render(out, here)
    if "--render" in sys.argv or "--play" in sys.argv:
        render_play(out, here.parent / "android" / "store-assets")
