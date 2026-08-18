#!/usr/bin/env python3
"""Generates the Gold Rush app icon.

Written by hand rather than pulled from a design tool because this project
takes no third-party dependencies and the build box has no image library.
Shapes are signed-distance fields, so edges are analytically anti-aliased
instead of supersampled -- one pass over the pixels, no 4x buffer.
"""
import zlib, struct, math, sys

S = 1024

def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def smoothstep(edge0, edge1, x):
    if edge1 == edge0:
        return 0.0 if x < edge0 else 1.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)

def sd_circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r

def sd_triangle(px, py, ax, ay, bx, by, cx, cy):
    """Negative inside. Standard half-plane test, sufficient for convex shapes."""
    def edge(x0, y0, x1, y1):
        ex, ey = x1 - x0, y1 - y0
        length = math.hypot(ex, ey)
        if length == 0:
            return 1e9
        # Outward normal for clockwise winding.
        nx, ny = ey / length, -ex / length
        return (px - x0) * nx + (py - y0) * ny
    return max(edge(ax, ay, bx, by), edge(bx, by, cx, cy), edge(cx, cy, ax, ay))

DIRT_DEEP = (18, 14, 11)
DIRT = (38, 31, 24)
GOLD = (217, 166, 56)
GOLD_BRIGHT = (250, 205, 90)
SLATE = (58, 50, 41)

rows = []
cx = cy = S / 2
max_r = math.hypot(cx, cy)

for y in range(S):
    row = bytearray()
    for x in range(S):
        # Radial vignette background.
        d = math.hypot(x - cx, y - cy) / max_r
        col = lerp(DIRT, DIRT_DEEP, smoothstep(0.15, 1.0, d))

        # The nugget: a gold disc high in the frame with a brighter core.
        nug = sd_circle(x, y, S * 0.5, S * 0.40, S * 0.175)
        a = 1.0 - smoothstep(-1.5, 1.5, nug)
        if a > 0:
            shine = smoothstep(S * 0.18, -S * 0.10, (x - S * 0.44) + (y - S * 0.34))
            col = lerp(col, lerp(GOLD, GOLD_BRIGHT, shine), a)

        # Two mountain silhouettes, the near one lighter so they read as depth.
        far = sd_triangle(x, y, S * 0.50, S * 0.46, S * 0.94, S * 0.86, S * 0.06, S * 0.86)
        a = 1.0 - smoothstep(-1.5, 1.5, far)
        if a > 0:
            col = lerp(col, SLATE, a * 0.92)

        near = sd_triangle(x, y, S * 0.30, S * 0.58, S * 0.66, S * 0.88, S * -0.06, S * 0.88)
        a = 1.0 - smoothstep(-1.5, 1.5, near)
        if a > 0:
            col = lerp(col, lerp(SLATE, DIRT_DEEP, 0.45), a)

        # Ground line in gold, the "pay streak".
        streak = abs(y - S * 0.855) - S * 0.006
        a = 1.0 - smoothstep(-1.0, 1.0, streak)
        if a > 0:
            col = lerp(col, GOLD, a * 0.85)

        row += bytes(int(max(0, min(255, round(c)))) for c in col)
    rows.append(row)

raw = b"".join(b"\x00" + bytes(r) for r in rows)

def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))

out = sys.argv[1] if len(sys.argv) > 1 else "icon.png"
with open(out, "wb") as f:
    f.write(png)
print(f"wrote {out} ({len(png)} bytes, {S}x{S})")
