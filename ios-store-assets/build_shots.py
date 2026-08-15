#!/usr/bin/env python3
"""App Store ekran görüntülerini üretir — 5 sahne × 2 dil, 1320x2868.

Sahneler oyunun gerçek çizim kurallarıyla kurulur: Nebula paleti, halka
stroke'u + parıltısı, kapının dönen kesikli dış çemberi, kırmızı tehlike
yayları, altın lümen, kürenin sönümlenen izi. Metin katmanı dilden dile
değiştiği için işaretleme elle tekrar edilmiyor, buradan üretiliyor.
"""
import math

W, H = 1320, 2868

RING   = "#7A68EE"
GATE   = "#4AF2C9"
HAZARD = "#FF4D6A"
LUMEN  = "#FFD35A"
TRAIL  = "#A38BFF"


def star_path(cx, cy, outer, inner, points=5, rot=-90.0):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180.0 / points)
        pts.append(f"{cx + math.cos(a) * r:.1f} {cy + math.sin(a) * r:.1f}")
    return "M " + " L ".join(pts) + " Z"


def ring(cx, cy, r, color=RING, glow=28, w=7, op=".9", f="b"):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{color}" stroke-width="{glow}"'
            f' fill="none" opacity=".22" filter="url(#{f})"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{color}" stroke-width="{w}"'
            f' fill="none" opacity="{op}"/>')


def gate(cx, cy, r, locked=False, f="b"):
    dim = ".38" if locked else "1"
    out = f'<g opacity="{dim}">'
    out += (f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{GATE}" stroke-width="32"'
            f' fill="none" opacity=".26" filter="url(#{f})"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke="{GATE}" stroke-width="7"'
            f' fill="none" opacity=".95"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{GATE}" opacity=".08"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r + 30}" stroke="{GATE}" stroke-width="5"'
            f' fill="none" stroke-dasharray="20 26" opacity=".7"/>')
    out += "</g>"
    if locked:
        out += (f'<g opacity=".6" fill="none" stroke="{GATE}" stroke-width="9">'
                f'<rect x="{cx - 40}" y="{cy - 4}" width="80" height="62" rx="13"'
                f' fill="{GATE}" opacity=".35" stroke="none"/>'
                f'<path d="M {cx - 24} {cy - 4} v -24 a 24 24 0 0 1 48 0 v 24"/></g>')
    return out


def orb(cx, cy, f="b", fs="s", r=22):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r * 3.7:.0f}" fill="{TRAIL}" opacity=".60" filter="url(#{f})"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * 1.35:.0f}" fill="#fff" opacity=".9" filter="url(#{fs})"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#fff"/>')


def trail(x0, y0, x1, y1, f="b"):
    out = ""
    for i, (rr, op) in enumerate([(10, .22), (14, .32), (18, .45), (22, .60)]):
        t = (i + 1) / 5
        out += (f'<circle cx="{x0 + (x1 - x0) * t:.0f}" cy="{y0 + (y1 - y0) * t:.0f}"'
                f' r="{rr}" fill="{TRAIL}" opacity="{op}"/>')
    return out


def lumen(cx, cy, f="b"):
    return (f'<circle cx="{cx}" cy="{cy}" r="38" fill="{LUMEN}" opacity=".30" filter="url(#{f})"/>'
            f'<circle cx="{cx}" cy="{cy}" r="18" fill="{LUMEN}"/>')


def grand(cx, cy, f="b"):
    return (f'<circle cx="{cx}" cy="{cy}" r="72" fill="{LUMEN}" opacity=".26" filter="url(#{f})"/>'
            f'<path d="{star_path(cx, cy, 54, 23)}" fill="{LUMEN}"/>')


def hazard_arc(cx, cy, r, a0, a1, f="b"):
    x0, y0 = cx + math.cos(math.radians(a0)) * r, cy + math.sin(math.radians(a0)) * r
    x1, y1 = cx + math.cos(math.radians(a1)) * r, cy + math.sin(math.radians(a1)) * r
    large = 1 if (a1 - a0) % 360 > 180 else 0
    d = f"M {x0:.0f} {y0:.0f} A {r} {r} 0 {large} 1 {x1:.0f} {y1:.0f}"
    return (f'<path d="{d}" stroke="{HAZARD}" stroke-width="38" stroke-linecap="round"'
            f' fill="none" opacity=".30" filter="url(#{f})"/>'
            f'<path d="{d}" stroke="{HAZARD}" stroke-width="24" stroke-linecap="round" fill="none"/>')


DEFS = ('<defs>'
        '<filter id="b" x="-90%" y="-90%" width="280%" height="280%">'
        '<feGaussianBlur stdDeviation="18"/></filter>'
        '<filter id="s" x="-90%" y="-90%" width="280%" height="280%">'
        '<feGaussianBlur stdDeviation="9"/></filter></defs>')


def hud(level, pips_on, total=3):
    pips = "".join(
        f'<div class="pip{" on" if i < pips_on else ""}"></div>' for i in range(total))
    return (f'<div class="hud"><div class="hud-btn"><span></span></div>'
            f'<div class="hud-lvl">{level}</div><div class="pips">{pips}</div></div>')


def scene_core():
    s = DEFS
    s += ring(900, 2580, 150) + ring(400, 2210, 134) + ring(950, 1830, 140) + ring(380, 1450, 132)
    s += gate(900, 1060, 145)
    s += trail(400, 2210, 682, 2014)
    s += orb(682, 2014)
    s += lumen(790, 1930) + lumen(640, 1640) + lumen(1140, 2340)
    return s


def scene_hazard():
    s = DEFS
    s += ring(400, 2500, 155)
    s += ('<path d="M 400 2315 A 185 185 0 0 1 582 2532" stroke="#FF4D6A" stroke-width="13"'
          ' stroke-linecap="round" fill="none" opacity=".95" filter="url(#s)"/>'
          '<path d="M 400 2315 A 185 185 0 0 1 582 2532" stroke="#FF4D6A" stroke-width="10"'
          ' stroke-linecap="round" fill="none"/>')
    s += orb(400, 2345)
    s += ring(950, 2120, 140) + hazard_arc(950, 2120, 140, -45, 45)
    s += ring(420, 1720, 132) + hazard_arc(420, 1720, 132, 135, 225)
    s += ring(920, 1330, 138)
    s += lumen(700, 2320) + lumen(680, 1930) + lumen(1120, 1560)
    return s


def scene_collect():
    s = DEFS
    s += gate(880, 1130, 150, locked=True)
    s += ring(900, 2620, 150) + ring(380, 2270, 145) + ring(930, 1900, 132) + ring(380, 1530, 138)
    s += trail(380, 2270, 704, 2060)
    s += orb(704, 2060)
    s += lumen(620, 1780) + lumen(1130, 2300) + lumen(650, 1370)
    return s


def scene_grand():
    s = DEFS
    s += ring(880, 2560, 150) + ring(380, 2200, 138) + ring(950, 1820, 132)
    s += gate(520, 1240, 145)
    s += trail(380, 2200, 660, 2010)
    s += orb(660, 2010)
    s += grand(1030, 1520)
    return s


def scene_endless():
    """Sonsuz mod: kamera yukarı bakar, halkalar yukarı doğru incelir."""
    s = DEFS
    s += ring(860, 2600, 142) + ring(400, 2270, 128) + ring(900, 1960, 118)
    s += ring(420, 1660, 108) + ring(880, 1400, 98) + ring(470, 1170, 88)
    s += trail(400, 2270, 690, 2100)
    s += orb(690, 2100)
    s += lumen(700, 1820) + lumen(640, 1500)
    return s


SCENES = [
    ("core",    scene_core,    lambda L: hud("14", 2)),
    ("hazard",  scene_hazard,  lambda L: hud("37", 1)),
    ("collect", scene_collect, lambda L: hud("88", 1)),
    ("grand",   scene_grand,   lambda L: hud("92", 0, total=4)),
    ("endless", scene_endless, lambda L: ""),
]

COPY = {
 "tr": [
  ("Tek dokunuş.<br>Halkadan <em>halkaya</em>.",
   "Küre yörüngede döner.<br>Doğru anı sen seçersin."),
  ("Kırmızıya<br>dokunma.",
   "Dönen tehlike yayları, süzülen halkalar<br>ve tükenen bir geri sayım."),
  ("Kapı <span class='teal'>kilitli</span>.<br>Işıkları topla.",
   "Yeşile konmak yetmez — haritayı süpür.<br>Yanarsan tur sıfırdan başlar."),
  ("Bir yıldız,<br><em>dört eder</em>.",
   "Hattından sapmayı göze al,<br>dev yıldız senin olsun."),
  ("Sonsuz mod.<br><em>Nereye kadar?</em>",
   "Yukarı çıktıkça hızlanır.<br>Haftalık sıralamada yerini al."),
 ],
 "en": [
  ("One tap.<br>Ring to <em>ring</em>.",
   "The orb circles its ring.<br>You pick the moment to let go."),
  ("Never touch<br>the red.",
   "Rotating hazard arcs, drifting rings<br>and a countdown running out."),
  ("The gate is <span class='teal'>locked</span>.<br>Collect the light.",
   "Landing on green is not enough — sweep<br>the map. One miss restarts the round."),
  ("One star,<br><em>worth four</em>.",
   "Leave your line to earn it.<br>The risk is yours to take."),
  ("Endless mode.<br><em>How far?</em>",
   "It speeds up the higher you climb.<br>Take your place on the weekly board."),
 ],
}

CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#000; font-family:"Inter","Inter Display",Helvetica,Arial,sans-serif; }
.shot { position:relative; width:1320px; height:2868px; overflow:hidden;
  background:linear-gradient(180deg,#0E0B29 0%,#170A38 52%,#210B44 100%); }
.bloom-a { position:absolute; width:1500px; height:1500px; left:-330px; top:-420px;
  background:radial-gradient(circle,rgba(163,139,255,0.22) 0%,rgba(163,139,255,0) 66%); }
.bloom-b { position:absolute; width:1200px; height:1200px; right:-320px; bottom:-380px;
  background:radial-gradient(circle,rgba(255,211,90,0.10) 0%,rgba(255,211,90,0) 66%); }
.star { position:absolute; border-radius:50%; background:#fff; }
.copy { position:absolute; left:0; right:0; top:190px; text-align:center; padding:0 90px; z-index:5; }
.head { font-size:104px; font-weight:800; letter-spacing:-2px; line-height:1.06; color:#fff;
  text-shadow:0 0 60px rgba(163,139,255,0.55); }
.head em { font-style:normal; color:#FFD35A; }
.head .teal { color:#4AF2C9; }
.sub { margin-top:34px; font-size:42px; font-weight:500; line-height:1.35;
  color:rgba(255,255,255,0.62); }
.hud { position:absolute; left:0; right:0; top:70px; display:flex; align-items:center;
  justify-content:space-between; padding:0 78px; z-index:6; }
.hud-btn { width:84px; height:84px; border-radius:50%; background:rgba(255,255,255,0.12);
  display:flex; align-items:center; justify-content:center; }
.hud-btn span { display:block; width:8px; height:30px; background:rgba(255,255,255,0.85);
  box-shadow:16px 0 0 rgba(255,255,255,0.85); margin-right:16px; }
.hud-lvl { font-size:38px; font-weight:700; color:rgba(255,255,255,0.75); letter-spacing:3px; }
.pips { display:flex; gap:14px; }
.pip { width:24px; height:24px; border-radius:50%; background:rgba(255,255,255,0.2); }
.pip.on { background:#FFD35A; box-shadow:0 0 18px rgba(255,211,90,0.9); }
svg.scene { position:absolute; left:0; top:0; }
.hud-score { font-size:64px; font-weight:800; color:#fff;
  text-shadow:0 0 34px rgba(163,139,255,.85); }
"""

STARS = [(180, 820, 4, .5), (1040, 1180, 5, .6), (320, 2260, 4, .45),
         (980, 2520, 5, .5), (660, 1560, 4, .4), (240, 1300, 4, .45)]


def build():
    shots = []
    for lang in ("tr", "en"):
        for i, (name, scene_fn, hud_fn) in enumerate(SCENES):
            head, sub = COPY[lang][i]
            stars = "".join(
                f'<div class="star" style="width:{s}px;height:{s}px;left:{x}px;top:{y}px;opacity:{o}"></div>'
                for (x, y, s, o) in STARS)
            extra = hud_fn(lang)
            if name == "endless":
                # Sonsuz modda bölüm numarası yerine skor var; HUD satırında
                # dursun ki başlığın altına girip onun parçası gibi okunmasın
                extra = ('<div class="hud"><div class="hud-btn"><span></span></div>'
                         '<div class="hud-score">31</div>'
                         '<div style="width:84px"></div></div>')
            shots.append(
                f'<div class="shot" id="{lang}{i+1}">'
                f'<div class="bloom-a"></div><div class="bloom-b"></div>{stars}'
                f'{extra}'
                f'<div class="copy"><div class="head">{head}</div>'
                f'<div class="sub">{sub}</div></div>'
                f'<svg class="scene" width="{W}" height="{H}">{scene_fn()}</svg>'
                f'</div>')
    return ("<!DOCTYPE html><html><head><meta charset='utf-8'><style>"
            + CSS + "</style></head><body>" + "".join(shots) + "</body></html>")


if __name__ == "__main__":
    import pathlib
    out = pathlib.Path(__file__).with_name("shots.html")
    out.write_text(build(), encoding="utf-8")
    print("yazıldı:", out)
