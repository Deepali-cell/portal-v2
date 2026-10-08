#!/usr/bin/env python3
"""Fetch a company's branding from the control server and generate its
Android launcher icons.

Usage: brand_assets.py <COMPANY_ID> <CONTROL_URL> <OUT_DIR>

Writes <OUT_DIR>/res/mipmap-*/ (legacy + adaptive icons) and prints the
resolved company as JSON on stdout. Uses the company logo from Customer
Tenant when one is set, otherwise the company initials on its brand colours.
"""
import io
import json
import os
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageFont

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
HEADERS = {"Accept": "application/json", "ngrok-skip-browser-warning": "1"}


def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def hex_color(s, fallback):
    s = (s or "").strip().lstrip("#")
    if len(s) != 6:
        s = fallback
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def initials(name):
    words = [w for w in name.replace("(", " ( ").split() if w.isalnum()]
    stop = words.index("(") if "(" in words else len(words)
    words = words[:stop] or ["?"]
    first = words[0]
    if first.isupper() and 2 <= len(first) <= 4:
        return first
    return "".join(w[0] for w in words[:2]).upper()


def gradient(size, c1, c2):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))
    return img


def text_layer(size, text, box):
    """White text centred in a transparent square, fitted into `box` px."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fs = size
    while fs > 4:
        font = ImageFont.truetype(FONT, fs)
        l, t, r, b = d.textbbox((0, 0), text, font=font)
        if r - l <= box and b - t <= box * 0.62:
            break
        fs -= 2
    d.text(((size - (r - l)) / 2 - l, (size - (b - t)) / 2 - t), text,
           font=font, fill="white")
    return layer


def fit_logo(logo, size, box):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    lg = logo.copy()
    lg.thumbnail((box, box), Image.LANCZOS)
    layer.paste(lg, ((size - lg.width) // 2, (size - lg.height) // 2), lg)
    return layer


def rounded(img, radius_ratio=0.22):
    size = img.width
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    company_id, control, out_dir = sys.argv[1], sys.argv[2].rstrip("/"), sys.argv[3]
    q = urllib.parse.urlencode({"company_id": company_id})
    data = json.loads(fetch(
        f"{control}/api/method/tcb_portal_control.api.tenant.resolve?{q}"))
    t = data["message"]
    name = t["company_name"]
    c2 = hex_color(t.get("color_p2"), "022B60")
    c3 = hex_color(t.get("color_p3"), "1F4FD8")

    logo = None
    raw = (t.get("logo_url") or "").strip()
    if raw:
        if raw.startswith("/"):
            raw = control + raw
        elif not raw.startswith("http"):
            raw = f"{control}/files/{raw}"
        try:
            logo = Image.open(io.BytesIO(fetch(raw))).convert("RGBA")
        except Exception as e:  # fall back to initials
            print(f"warning: logo download failed ({e}); using initials",
                  file=sys.stderr)

    res = os.path.join(out_dir, "res")
    for dens, k in DENSITIES.items():
        d = os.path.join(res, f"mipmap-{dens}")
        os.makedirs(d, exist_ok=True)
        legacy = round(48 * k)
        adaptive = round(108 * k)
        if logo:
            bg = Image.new("RGB", (legacy, legacy), "white")
            bg = Image.alpha_composite(bg.convert("RGBA"),
                                       fit_logo(logo, legacy, legacy * 0.72))
            rounded(bg).save(os.path.join(d, "ic_launcher.png"))
            Image.new("RGB", (adaptive, adaptive), "white").save(
                os.path.join(d, "ic_launcher_background.png"))
            fit_logo(logo, adaptive, adaptive * 0.56).save(
                os.path.join(d, "ic_launcher_foreground.png"))
        else:
            mark = initials(name)
            bg = gradient(legacy, c2, c3).convert("RGBA")
            bg = Image.alpha_composite(bg, text_layer(legacy, mark, legacy * 0.66))
            rounded(bg).save(os.path.join(d, "ic_launcher.png"))
            gradient(adaptive, c2, c3).save(
                os.path.join(d, "ic_launcher_background.png"))
            text_layer(adaptive, mark, adaptive * 0.48).save(
                os.path.join(d, "ic_launcher_foreground.png"))

    anydpi = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n')

    print(json.dumps({"company_id": t["company_id"], "company_name": name,
                      "has_logo": logo is not None}))


if __name__ == "__main__":
    main()
