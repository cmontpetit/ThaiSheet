#!/usr/bin/env python3
"""Frame and caption raw App Store screenshots.

Reads the raw PNGs written by capture_app_store_screenshots.sh and writes
JPEGs (no alpha, as App Store Connect requires) at the raw screenshot's own
pixel size, so the 6.9" iPhone and 13" iPad sets keep their upload sizes.

    python3 scripts/frame_app_store_screenshots.py <raw-dir> <output-dir> <set>

Captions and order come from scripts/app_store_screenshots.json. The
background gradient uses the app icon's blue-teal (scripts/generate_icon.py).
Requires Pillow and macOS system fonts.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CONFIG = Path(__file__).resolve().parent / "app_store_screenshots.json"
SF = "/System/Library/Fonts/SFNS.ttf"
THAI = "/System/Library/Fonts/Supplemental/Thonburi.ttc"  # 0 Regular, 1 Bold

TOP, BOTTOM = (38, 80, 148), (48, 166, 158)
BEZEL = (22, 24, 28)
BEZEL_EDGE = (70, 74, 82)


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


def thai_font(size: int, bold: bool) -> ImageFont.FreeTypeFont:
    # Thonburi's letters are small next to SF at the same point size
    return ImageFont.truetype(THAI, round(size * 1.3), index=1 if bold else 0)


def is_thai(ch: str) -> bool:
    return "฀" <= ch <= "๿"


def runs(text: str, latin: ImageFont.FreeTypeFont, thai: ImageFont.FreeTypeFont):
    """Split text into (string, font) runs so Thai uses a Thai font."""
    out: list[tuple[str, ImageFont.FreeTypeFont]] = []
    for ch in text:
        f = thai if is_thai(ch) else latin
        if out and out[-1][1] is f:
            out[-1] = (out[-1][0] + ch, f)
        else:
            out.append((ch, f))
    return out


def text_width(text, latin, thai) -> float:
    return sum(f.getlength(s) for s, f in runs(text, latin, thai))


def wrap(text, latin, thai, max_width) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and text_width(trial, latin, thai) > max_width:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line] if line else lines


def draw_centered(draw, lines, latin, thai, center_x, y, fill, line_height) -> float:
    for line in lines:
        x = center_x - text_width(line, latin, thai) / 2
        baseline = y + latin.getmetrics()[0]  # shared baseline across fonts
        for s, f in runs(line, latin, thai):
            draw.text((x, baseline), s, font=f, fill=fill, anchor="ls")
            x += f.getlength(s)
        y += line_height
    return y


def gradient(size) -> Image.Image:
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize((w, h))


def rounded_mask(size, radius) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def frame(raw: Image.Image, title: str, subtitle: str, corner_ratio: float) -> Image.Image:
    W, H = raw.size
    landscape = W > H
    canvas = gradient((W, H))
    draw = ImageDraw.Draw(canvas)

    short = min(W, H)
    title_size = round(short * (0.06 if landscape else 0.064))
    sub_size = round(title_size * 0.55)
    title_latin, title_thai = font(title_size, "Bold"), thai_font(title_size, True)
    sub_latin, sub_thai = font(sub_size, "Medium"), thai_font(sub_size, False)

    # Fixed caption band, so the device sits at the same place on every shot
    band = round(H * (0.2 if landscape else 0.165))
    margin = round(W * 0.06)
    title_lines = wrap(title, title_latin, title_thai, W - 2 * margin)
    sub_lines = wrap(subtitle, sub_latin, sub_thai, W - 2 * margin)
    title_lh, sub_lh, gap = round(title_size * 1.15), round(sub_size * 1.3), round(sub_size * 0.5)
    block = len(title_lines) * title_lh + gap + len(sub_lines) * sub_lh
    y = (band - block) / 2 + round(H * 0.01)
    y = draw_centered(draw, title_lines, title_latin, title_thai, W / 2, y, "white", title_lh)
    draw_centered(draw, sub_lines, sub_latin, sub_thai, W / 2, y + gap,
                  (226, 238, 245), sub_lh)

    # Device: bezel around the screenshot, wide enough to read the tables;
    # its bottom runs off the canvas
    bezel = round(short * 0.022)
    scale = (W * (0.8 if landscape else 0.86)) / (W + 2 * bezel)
    sw, sh = round(W * scale), round(H * scale)
    b = round(bezel * scale)
    dw, dh = sw + 2 * b, sh + 2 * b
    dx, dy = round((W - dw) / 2), band
    screen_r = round(min(sw, sh) * corner_ratio)
    device_r = screen_r + b

    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (dx, dy + round(H * 0.012), dx + dw, dy + dh + round(H * 0.012)), radius=device_r, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(short * 0.02)))
    canvas.paste((10, 25, 50), (0, 0), shadow)

    device = Image.new("RGB", (dw, dh), BEZEL)
    ImageDraw.Draw(device).rounded_rectangle(
        (0, 0, dw - 1, dh - 1), radius=device_r, outline=BEZEL_EDGE, width=max(2, round(b * 0.12)))
    screen = raw.convert("RGB").resize((sw, sh), Image.LANCZOS)
    device.paste(screen, (b, b), rounded_mask((sw, sh), screen_r))
    canvas.paste(device, (dx, dy), rounded_mask((dw, dh), device_r))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("raw_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("set", help="iphone, ipad, duo-open, or duo-closed")
    args = parser.parse_args()

    config = json.loads(CONFIG.read_text())["sets"][args.set]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, shot in enumerate(config["shots"], start=1):
        name = f"{index:02d}-{shot['scenario']}"
        raw = Image.open(args.raw_dir / f"{name}.png")
        framed = frame(raw, shot["title"], shot["subtitle"], config["corner_ratio"])
        out = args.output_dir / f"{name}.jpg"
        framed.save(out, "JPEG", quality=92)
        print(f"Framed {out} ({framed.width}x{framed.height})")


if __name__ == "__main__":
    main()
