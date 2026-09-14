#!/usr/bin/env python3
"""Generate the Gold Rush Google Play feature graphic from the shipping palette."""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 500

DIRT_DEEP = (11, 9, 8)
DIRT = (22, 18, 15)
DIRT_WARM = (45, 33, 23)
DIRT_LIGHT = (41, 34, 28)
EMBER = (83, 54, 25)
GOLD = (225, 175, 60)
GOLD_BRIGHT = (252, 216, 126)
GOLD_DEEP = (139, 99, 27)
PARCHMENT = (239, 232, 216)
SLUICE = (92, 150, 170)

MINING_COLORS = [
    GOLD_BRIGHT,
    (204, 133, 71),
    (140, 148, 158),
    (148, 135, 120),
    SLUICE,
    (179, 194, 217),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    raise SystemExit("No supported sans-serif font found on runner")


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def background() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT), DIRT_DEEP)
    pixels = image.load()
    cx, cy = 640.0, 235.0
    max_r = math.hypot(max(cx, WIDTH - cx), max(cy, HEIGHT - cy))
    for y in range(HEIGHT):
        for x in range(WIDTH):
            distance = math.hypot(x - cx, y - cy) / max_r
            radial = max(0.0, 1.0 - min(distance, 1.0))
            vertical = y / HEIGHT
            t = min(1.0, radial * 0.58 + (1.0 - vertical) * 0.08)
            pixels[x, y] = tuple(lerp(DIRT_DEEP[i], DIRT_WARM[i], t) for i in range(3))

    draw = ImageDraw.Draw(image)
    rng = random.Random(20260913)
    for _ in range(150):
        x = rng.randrange(0, WIDTH)
        y = rng.randrange(0, HEIGHT)
        radius = rng.choice([1, 1, 1, 2])
        opacity = rng.randrange(18, 46)
        base = image.getpixel((x, y))
        dot = tuple(lerp(base[i], GOLD_DEEP[i], opacity / 255.0) for i in range(3))
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=dot)
    return image


def rounded_panel(size: tuple[int, int], angle: float, accent: tuple[int, int, int], hidden_on_left: bool) -> Image.Image:
    w, h = size
    panel = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    draw.rounded_rectangle((3, 3, w - 4, h - 4), radius=24, fill=(*DIRT, 245), outline=(*GOLD_DEEP, 210), width=3)
    draw.rounded_rectangle((17, 17, w - 18, h - 18), radius=18, outline=(*accent, 105), width=2)

    label = "PILE A" if hidden_on_left else "PILE B"
    draw.text((26, 24), label, fill=GOLD_BRIGHT, font=font(20, bold=True))

    chip_y = 78
    positions = [42, 100, 158]
    colors = MINING_COLORS[:3] if hidden_on_left else MINING_COLORS[3:]
    for x, color in zip(positions, colors):
        draw.ellipse((x, chip_y, x + 38, chip_y + 38), fill=(*color, 255), outline=(*PARCHMENT, 60), width=1)
        draw.ellipse((x + 8, chip_y + 8, x + 30, chip_y + 30), outline=(*DIRT_DEEP, 100), width=2)

    card_x = 214
    if hidden_on_left:
        draw.rounded_rectangle((card_x, 67, card_x + 54, 127), radius=9, fill=(*EMBER, 255), outline=(*SLUICE, 230), width=3)
        draw.text((card_x + 18, 77), "?", fill=SLUICE, font=font(31, bold=True))
    else:
        draw.rounded_rectangle((card_x, 67, card_x + 54, 127), radius=9, fill=(*GOLD_DEEP, 255), outline=(*GOLD, 220), width=3)
        draw.ellipse((card_x + 13, 81, card_x + 41, 109), fill=(*GOLD_BRIGHT, 255))

    return panel.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)


def make(output: Path) -> None:
    image = background()
    draw = ImageDraw.Draw(image)

    # Keep all critical copy within Google's center-safe area.
    draw.text((205, 150), "SPLIT THE CLAIM.", fill=GOLD_BRIGHT, font=font(46, bold=True))
    draw.text((205, 211), "THEY CHOOSE.", fill=PARCHMENT, font=font(46, bold=True))
    draw.rounded_rectangle((205, 292, 474, 297), radius=2, fill=GOLD_DEEP)
    draw.text((205, 321), "Hidden information. Sharp scoring.", fill=(190, 180, 162), font=font(19))

    pile_a = rounded_panel((300, 158), -6.0, GOLD, True)
    pile_b = rounded_panel((300, 158), 6.0, SLUICE, False)

    image.paste(pile_a, (605, 83), pile_a)
    image.paste(pile_b, (624, 260), pile_b)

    # A subtle split marker ties the graphic to the core mechanic without
    # duplicating the app icon beside the store icon.
    draw.line((588, 80, 588, 420), fill=GOLD_DEEP, width=2)
    draw.ellipse((580, 238, 596, 254), fill=GOLD, outline=GOLD_BRIGHT, width=2)

    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG", optimize=True)

    check = Image.open(output)
    if check.mode != "RGB":
        raise SystemExit(f"Feature graphic must be 24-bit RGB, got {check.mode}")
    if check.size != (WIDTH, HEIGHT):
        raise SystemExit(f"Feature graphic has wrong dimensions: {check.size}")
    print(f"Wrote {output} ({output.stat().st_size} bytes, {check.mode}, {check.size})")


if __name__ == "__main__":
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("generated/play-store/feature-graphic.png")
    make(destination)
