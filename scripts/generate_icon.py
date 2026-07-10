#!/usr/bin/env python3
"""Generate the ThaiSheet app icon set (light, dark, tinted).

Writes AppIcon.png, AppIcon-dark.png, and AppIcon-tinted.png directly into
ThaiSheet/Assets.xcassets/AppIcon.appiconset/ (filenames referenced by its
Contents.json).

Design: full-bleed blue-to-teal gradient (no pre-rounded corners — iOS applies
its own mask), a cheatsheet card with one vertical and one horizontal table
rule, the bold Thonburi ก in the large cell, and three chips in the app's
consonant-class colors (green/yellow/red = low/mid/high). The tinted variant
is grayscale per Apple's spec, with the chips at three luminance steps kept
lighter than the glyph so they don't compete with it.

Requires Pillow (`python3 -m pip install --user pillow`) and macOS (uses the
system Thonburi font).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
FONT_PATH = "/System/Library/Fonts/Supplemental/Thonburi.ttc"
FONT_BOLD_INDEX = 1
OUT_DIR = Path(__file__).resolve().parent.parent / "ThaiSheet/Assets.xcassets/AppIcon.appiconset"

# Consonant-class chip colors (light, dark variants)
GREEN, YELLOW, RED = (96, 190, 125), (235, 200, 90), (228, 110, 100)
GREEN_D, YELLOW_D, RED_D = (76, 158, 102), (200, 168, 70), (196, 90, 82)


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        row = tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3))
        for x in range(size):
            px[x, y] = row
    return img


def make_icon(bg_top, bg_bottom, card, grid, glyph_color, chips, shadow_alpha=70):
    img = vertical_gradient(S, bg_top, bg_bottom).convert("RGBA")
    m = 175
    box = (m, m, S - m, S - m)
    radius = 52

    if shadow_alpha:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle(
            (box[0] + 10, box[1] + 22, box[2] + 10, box[3] + 22),
            radius=radius, fill=(10, 25, 50, shadow_alpha))
        sh = sh.filter(ImageFilter.GaussianBlur(28))
        img = Image.alpha_composite(img, sh)

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=radius, fill=card)

    # Table rules: 10px stays visible (~0.6px) after the 16x shrink to 64pt;
    # tune prominence via the grid color, not the thickness
    gw = 10
    vx = box[0] + int((box[2] - box[0]) * 0.68)
    hy = box[1] + int((box[3] - box[1]) * 0.30)
    d.rectangle((vx, box[1], vx + gw, box[3]), fill=grid)
    d.rectangle((box[0], hy, box[2], hy + gw), fill=grid)

    chip_r = 17
    chip_x = (vx + gw + box[2]) // 2
    cy0, cy1 = box[1] + 62, hy - 62
    step = (cy1 - cy0) / 2
    for i, color in enumerate(chips):
        cy = cy0 + step * i
        d.rounded_rectangle(
            (chip_x - 52, cy - chip_r, chip_x + 52, cy + chip_r),
            radius=chip_r, fill=color)

    img = Image.alpha_composite(img, layer)

    font = ImageFont.truetype(FONT_PATH, 495, index=FONT_BOLD_INDEX)
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    bbox = gd.textbbox((0, 0), "ก", font=font, stroke_width=8)
    gwd, ghd = bbox[2] - bbox[0], bbox[3] - bbox[1]
    cx = (box[0] + vx) / 2
    cy = (hy + box[3]) / 2 - 6
    gd.text((cx - gwd / 2 - bbox[0], cy - ghd / 2 - bbox[1]), "ก", font=font,
            fill=glyph_color, stroke_width=8, stroke_fill=glyph_color)
    img = Image.alpha_composite(img, g)
    return img.convert("RGB")


def main():
    light = make_icon(
        (38, 80, 148), (48, 166, 158),
        (250, 249, 244, 255), (220, 223, 230, 255),
        (28, 55, 105, 255), [GREEN, YELLOW, RED])
    light.save(OUT_DIR / "AppIcon.png")

    dark = make_icon(
        (16, 34, 68), (18, 78, 76),
        (222, 224, 227, 255), (186, 190, 199, 255),
        (20, 40, 80, 255), [GREEN_D, YELLOW_D, RED_D], shadow_alpha=110)
    dark.save(OUT_DIR / "AppIcon-dark.png")

    # Tinted: grayscale; chip luminances stay lighter than the glyph so the
    # brand mark dominates, with three distinct steps to avoid reading as a
    # hamburger-menu icon
    tint = make_icon(
        (0, 0, 0), (0, 0, 0),
        (235, 235, 235, 255), (180, 180, 180, 255),
        (25, 25, 25, 255),
        [(190,) * 3, (150,) * 3, (110,) * 3], shadow_alpha=0)
    tint.convert("L").convert("RGB").save(OUT_DIR / "AppIcon-tinted.png")

    print(f"Wrote 3 icons to {OUT_DIR}")


if __name__ == "__main__":
    main()
