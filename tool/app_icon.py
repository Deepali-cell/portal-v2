#!/usr/bin/env python3
"""Generate the Workora app logo and every platform icon from it.

Usage: tool/app_icon.py   (run from anywhere; writes into the project)

Writes:
  assets/brand/app_logo.png                     in-app logo (no tenant yet)
  android/app/src/main/res/mipmap-*/            launcher icons (legacy + adaptive)
  ios/Runner/Assets.xcassets/AppIcon.appiconset/ iOS icons

Company-branded builds replace the Android icons with the company's own
(see tool/build_company_apk.sh); this is the generic app's identity.
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TOP = (79, 70, 229)      # indigo
BOTTOM = (124, 58, 237)  # violet
ACCENT = (251, 191, 36)  # amber
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
S = 1024  # master size; everything is drawn here and scaled down


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (0.35 * x + 0.65 * y) / (size - 1)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
    return img


def mark(scale):
    """The 'W' mark on a transparent S x S canvas, at `scale` of full size."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = S / 2
    w = S * 0.56 * scale          # mark width
    h = w * 0.52                  # mark height
    stroke = int(w * 0.15)
    top = c - h / 2 + w * 0.09
    pts = [
        (c - w / 2, top),
        (c - w / 4, top + h),
        (c, top + h * 0.38),
        (c + w / 4, top + h),
        (c + w / 2, top),
    ]
    d.line(pts, fill="white", width=stroke, joint="curve")
    r = stroke / 2
    for x, y in (pts[0], pts[-1], pts[1], pts[3]):
        d.ellipse((x - r, y - r, x + r, y + r), fill="white")
    # The "person" above the middle peak.
    dot = stroke * 0.72
    cy = top - dot * 0.55
    d.ellipse((c - dot, cy - dot, c + dot, cy + dot), fill=ACCENT)
    return layer


def rounded(img, ratio=0.23):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.width - 1, img.height - 1), radius=int(img.width * ratio), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def save(img, size, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(p)


def main():
    bg = gradient(S).convert("RGBA")
    full = Image.alpha_composite(bg, mark(1.0))          # square, edge to edge
    logo = rounded(full)                                  # with rounded corners

    save(logo, 512, "assets", "brand", "app_logo.png")

    res = ("android", "app", "src", "main", "res")
    fg = mark(0.72)  # adaptive foreground must sit in the 66% safe zone
    for dens, k in DENSITIES.items():
        save(logo, round(48 * k), *res, f"mipmap-{dens}", "ic_launcher.png")
        save(bg, round(108 * k), *res, f"mipmap-{dens}", "ic_launcher_background.png")
        save(fg, round(108 * k), *res, f"mipmap-{dens}", "ic_launcher_foreground.png")
    anydpi = os.path.join(ROOT, *res, "mipmap-anydpi-v26", "ic_launcher.xml")
    os.makedirs(os.path.dirname(anydpi), exist_ok=True)
    with open(anydpi, "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n')

    # iOS wants opaque, square icons (the OS rounds the corners).
    ios = ("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    with open(os.path.join(ROOT, *ios, "Contents.json")) as f:
        images = json.load(f)["images"]
    opaque = full.convert("RGB")
    for im in images:
        pt = float(im["size"].split("x")[0])
        px = round(pt * int(im["scale"].rstrip("x")))
        save(opaque, px, *ios, im["filename"])

    print("Workora icons written.")


if __name__ == "__main__":
    main()
