#!/usr/bin/env python3
"""App Store ekran görüntülerini üretir — 5 sahne × 3 dil, 1320x2868.

Sahneler oyunun GERÇEK çizim kurallarıyla kurulur: mat palet, parıltısız
halka çizgisi, kapının dönen kesikli dış çemberi, yeşilden kırmızıya eriyen
tehlike yayı, altın lümen, kürenin sönümlenen izi. Metin katmanı dilden dile
değiştiği için işaretleme elle tekrarlanmıyor, buradan üretiliyor.

Palet oyunun `Theme.nebula` değerleriyle birebir aynı; "tek vurgu" dilinde
anlam taşıyan üç renk (kapı ≈ beyaz, tehlike kırmızı, yıldız altın) bütün
temalarda sabit olduğu için mağaza görselleri de oyunla aynı şeyi gösteriyor.

Kullanım:
    python3 build_shots.py            # shots.html üretir
    python3 build_shots.py --render   # + PNG'leri yazar (Playwright ister)
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
]

COPY = {
 "tr": [
  ("Tek dokunuş.<br>Halkadan <em>halkaya</em>.",
   "Küre yörüngede döner.<br>Doğru anı sen seçersin."),
  ("İlk tur <span class='safe'>yakmaz</span>.<br>Sonrası sana kalmış.",
   "Yeşil eridikçe kırmızı kapanır.<br>Geri sayım yayın üstünde."),
  ("Kapı <span class='gate'>kilitli</span>.<br>Işıkları topla.",
   "Yeşile konmak yetmez — haritayı süpür.<br>Yanarsan tur sıfırdan başlar."),
  ("Yıldız topla,<br><em>karakter aç</em>.",
   "Her eşikte yeni bir küre.<br>257 bölüm, 806 yıldız."),
  ("Sonsuz mod.<br><em>Nereye kadar?</em>",
   "Yukarı çıktıkça hızlanır.<br>Haftalık sıralamada yerini al."),
 ],
 "en": [
  ("One tap.<br>Ring to <em>ring</em>.",
   "The orb circles its ring.<br>You pick the moment to let go."),
  ("First lap is <span class='safe'>free</span>.<br>After that, it burns.",
   "Green melts away, red closes in.<br>The countdown is on the arc itself."),
  ("The gate is <span class='gate'>locked</span>.<br>Collect the light.",
   "Landing on green is not enough — sweep<br>the map. One miss restarts the round."),
  ("Collect stars,<br><em>unlock characters</em>.",
   "A new orb at every milestone.<br>257 levels, 806 stars."),
  ("Endless mode.<br><em>How far?</em>",
   "It speeds up the higher you climb.<br>Take your place on the weekly board."),
 ],
 "es": [
  ("Un toque.<br>De anillo a <em>anillo</em>.",
   "La esfera gira en su anillo.<br>Tú eliges el momento de soltar."),
  ("La primera vuelta<br>no <span class='safe'>quema</span>.",
   "El verde se consume, el rojo avanza.<br>La cuenta atrás está en el propio arco."),
  ("La puerta está <span class='gate'>cerrada</span>.<br>Recoge la luz.",
   "Llegar al verde no basta: recorre<br>el mapa. Un fallo reinicia la ronda."),
  ("Reúne estrellas,<br><em>desbloquea personajes</em>.",
   "Una esfera nueva en cada meta.<br>257 niveles, 806 estrellas."),
  ("Modo infinito.<br><em>¿Hasta dónde?</em>",
   "Acelera cuanto más alto llegas.<br>Ocupa tu lugar en la tabla semanal."),
 ],
}

CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#000; font-family:"Inter","Inter Display",Helvetica,Arial,sans-serif; }}
.shot {{ position:relative; width:{W}px; height:{H}px; overflow:hidden;
  background:linear-gradient(180deg,{BG_TOP} 0%,{BG_BOTTOM} 100%); }}
.star {{ position:absolute; border-radius:50%; background:#fff; }}
.copy {{ position:absolute; left:0; right:0; top:200px; text-align:center; padding:0 90px; z-index:5; }}
.head {{ font-size:100px; font-weight:300; letter-spacing:-1px; line-height:1.1; color:#fff; }}
.head em {{ font-style:normal; font-weight:600; color:#fff; }}
.head .gate {{ color:{GATE}; }}
.head .safe {{ color:#6E9C74; }}
.sub {{ margin-top:38px; font-size:40px; font-weight:400; line-height:1.4;
  color:rgba(255,255,255,0.52); }}
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
svg.scene {{ position:absolute; left:0; top:0; }}
"""

STARS = [(180, 820, 4, .34), (1040, 1180, 5, .40), (320, 2260, 4, .30),
         (980, 2520, 5, .34), (660, 1560, 4, .26), (240, 1300, 4, .30)]

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
            if name == "endless":
                # Sonsuz modda bölüm numarası yerine skor var
                extra = ('<div class="hud"><div class="hud-btn"><span></span></div>'
                         '<div class="hud-score">31</div>'
                         '<div style="width:84px"></div></div>')
            elif name == "characters":
                extra = f'<div class="goal">{GOAL_COPY[lang]}</div>'
            shots.append(
                f'<div class="shot" id="{lang}{i+1}">{stars}{extra}'
                f'<div class="copy"><div class="head">{head}</div>'
                f'<div class="sub">{sub}</div></div>'
                f'<svg class="scene" width="{W}" height="{H}">{scene_fn()}</svg>'
                f'</div>')
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
        browser.close()


if __name__ == "__main__":
    here = pathlib.Path(__file__).parent
    out = here / "shots.html"
    out.write_text(build(), encoding="utf-8")
    print("yazıldı:", out)
    if "--render" in sys.argv:
        render(out, here)
