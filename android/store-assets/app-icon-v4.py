from PIL import Image, ImageDraw
import math

def hx(s):
    s = s.lstrip("#"); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4))

BG_T, BG_B = hx("#0E0E14"), hx("#1C1926")
RING, HAZ, ORB = hx("#807F8A"), hx("#D1495B"), hx("#F2F3F5")

def icon(size, ss=4):
    s = size * ss
    img = Image.new("RGB", (s, s)); d = ImageDraw.Draw(img)
    for y in range(s):
        f = y / (s - 1)
        d.line([(0, y), (s, y)], fill=tuple(int(BG_T[i] + (BG_B[i]-BG_T[i])*f) for i in range(3)))

    cx = cy = s / 2
    r  = s * 0.295
    w  = s * 0.037
    box = [cx-r, cy-r, cx+r, cy+r]
    d.ellipse(box, outline=RING, width=int(w))
    d.arc(box, -125, -31, fill=HAZ, width=int(w * 2.25))
    a = math.radians(118)
    ox, oy = cx + math.cos(a) * r, cy + math.sin(a) * r
    orr = s * 0.062
    d.ellipse([ox-orr, oy-orr, ox+orr, oy+orr], fill=ORB)
    return img.resize((size, size), Image.LANCZOS)

icon(1024).save("orbeon-icon-1024.png")
icon(512).save("orbeon-icon-512.png")
print("ok")
