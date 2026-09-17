# Orbeon 2.3 (build 10) — mağaza metinleri

**Yayına yapıştırılacak hâli `Orbeon-2.3-magaza-metinleri.pdf` dosyasında.**
Kaynağı `magaza-metinleri-2.3.html`; metni orada düzelt, PDF'i yeniden bas:

```sh
python3 - <<'EOF'
from playwright.sync_api import sync_playwright
import pathlib
src = pathlib.Path("magaza-metinleri-2.3.html").resolve()
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(); pg.goto(src.as_uri())
    pg.pdf(path="Orbeon-2.3-magaza-metinleri.pdf", format="A4", print_background=True)
    b.close()
EOF
```

PDF'te diller ayrı sayfada (TR · EN · ES), her sayfada üç alan var: tanıtım
metni, App Store yenilikleri, Play sürüm notu. Karakter sayıları elle değil
HTML'den hesaplanıp yazıldı.

Android: **versionCode 9 / versionName 2.3**.
Sayılar değişmedi: **257 bölüm, 806 yıldız, 22 karakter, 10 tema, 6 rütbe.**

> **Ekran görüntüleri 2.3'te yenilendi.** 2.2'dekiler artık geçerli değil —
> altı panelin de metni değişti, 36 PNG yeniden üretildi. Yükleyeceklerin
> `ios-store-assets/` (6.9") ve `ios-store-assets/6.5-inch/` altında,
> Play için `android/store-assets/`.

> **Kırmızı kapı sürüm notunun EN BAŞINDA, bilerek.** Eski oyuncu beyaz kapıyı
> "kısa yol" diye öğrendi; aynı yerde artık ölüyor ve bölümü baştan başlıyor.
> Bunu notun ortasına gömmek, oyuncunun onu ölerek öğrenmesi demek.
