#!/usr/bin/env python3
"""Generates the Gold Rush app icon.

Written by hand rather than pulled from a design tool because this project
takes no third-party dependencies and the build box has no image library.
Shapes are signed-distance fields, so edges are analytically anti-aliased
instead of supersampled -- one pass over the pixels, no 4x buffer.

The design has to survive being 40 points wide on a home screen, which rules
out scenery: the previous icon was a sun behind two mountains, and at that
size the mountains disappeared into the background and what was left could
have been a weather app. So this is one loud object -- a faceted gold nugget
-- over a warm ground, with two cards fanned behind it to say "card game"
without competing for attention. Facets rather than a flat disc because a
disc at 40 points is a dot; edges give it something to read as.
"""
import zlib, struct, math, sys

# Second argument renders a small copy, for checking the icon still reads at
# the size it will actually be looked at. The mountain design it replaced was
# fine at 1024 and gone at 80.
S = int(sys.argv[2]) if len(sys.argv) > 2 else 1024


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smoothstep(edge0, edge1, x):
    if edge1 == edge0:
        return 0.0 if x < edge0 else 1.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def sd_polygon(px, py, pts):
    """Signed distance to a convex polygon, negative inside.

    Points must wind clockwise in screen space (y down). Convex only, which
    every shape here is.
    """
    worst = -1e9
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        ex, ey = x1 - x0, y1 - y0
        length = math.hypot(ex, ey)
        if length == 0:
            continue
        nx, ny = ey / length, -ex / length
        worst = max(worst, (px - x0) * nx + (py - y0) * ny)
    return worst


def sd_round_rect(px, py, cx, cy, hw, hh, r, angle=0.0):
    """Rotated rounded rectangle, for the cards behind the nugget."""
    ca, sa = math.cos(-angle), math.sin(-angle)
    dx, dy = px - cx, py - cy
    rx, ry = dx * ca - dy * sa, dx * sa + dy * ca
    qx, qy = abs(rx) - (hw - r), abs(ry) - (hh - r)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    return outside + min(max(qx, qy), 0.0) - r


# Warmer and brighter than the app's board palette. An icon competes with
# every other icon on the screen, where the board only competes with itself.
GROUND_DEEP = (26, 16, 9)
GROUND_WARM = (92, 47, 14)
EMBER = (150, 78, 20)
CARD_BACK = (44, 28, 16)
CARD_EDGE = (168, 126, 58)
GOLD_DARK = (150, 96, 20)
GOLD = (224, 165, 44)
GOLD_BRIGHT = (255, 216, 112)
GOLD_WHITE = (255, 245, 205)

cx = cy = S / 2
max_r = math.hypot(cx, cy)

# The nugget, as facets rather than one blob. Coordinates are fractions of S,
# drawn once here so the silhouette and its facets cannot drift apart.
NUGGET = [
    (0.500, 0.205), (0.735, 0.330), (0.800, 0.560),
    (0.660, 0.775), (0.395, 0.800), (0.215, 0.640), (0.230, 0.375),
]
# Facet seams: each is a polygon lit differently from the body.
FACET_TOP = [(0.500, 0.205), (0.735, 0.330), (0.560, 0.470), (0.230, 0.375)]
FACET_LEFT = [(0.230, 0.375), (0.560, 0.470), (0.430, 0.690), (0.215, 0.640)]
FACET_RIGHT = [(0.735, 0.330), (0.800, 0.560), (0.660, 0.775), (0.430, 0.690), (0.560, 0.470)]


# The nugget was drawn full-frame first, which left the cards behind it as
# slivers. Shrinking it here rather than by rewriting every coordinate keeps
# the facet seams locked to the silhouette.
NUGGET_SCALE = 0.70
NUGGET_ORIGIN = (0.5075, 0.5025)
NUGGET_CENTRE = (0.500, 0.520)


def scaled(poly):
    ox, oy = NUGGET_ORIGIN
    tx, ty = NUGGET_CENTRE
    return [(((x - ox) * NUGGET_SCALE + tx) * S,
             ((y - oy) * NUGGET_SCALE + ty) * S) for x, y in poly]


NUGGET_PX = scaled(NUGGET)
FACET_TOP_PX = scaled(FACET_TOP)
FACET_LEFT_PX = scaled(FACET_LEFT)
FACET_RIGHT_PX = scaled(FACET_RIGHT)

rows = []
for y in range(S):
    row = bytearray()
    for x in range(S):
        # Ground: a warm pool of light behind the nugget, falling to near-black
        # in the corners so the icon has a defined edge on a light wallpaper.
        d = math.hypot(x - cx, y - cy * 1.02) / max_r
        col = lerp(GROUND_WARM, GROUND_DEEP, smoothstep(0.05, 0.78, d))
        glow = 1.0 - smoothstep(0.0, 0.52, d)
        col = lerp(col, EMBER, glow * 0.55)

        # Two cards fanned behind, one either side. They read as a pair of
        # piles -- the thing the game is actually about -- without needing to
        # be legible as cards at small sizes.
        for angle, ox, oy in ((-0.36, -0.170, 0.505), (0.36, 0.170, 0.505)):
            card = sd_round_rect(x, y, S * (0.5 + ox), S * oy,
                                 S * 0.158, S * 0.232, S * 0.030, angle)
            a = 1.0 - smoothstep(-1.5, 1.5, card)
            if a > 0:
                # Bright only in the last few pixels before the boundary. The
                # first version had this inverted and flooded the whole card
                # with the rim colour, which washed both of them out into tan
                # slabs competing with the nugget.
                edge = smoothstep(-S * 0.014, -S * 0.002, card)
                col = lerp(col, lerp(CARD_BACK, CARD_EDGE, edge), a)

        # The nugget body.
        nug = sd_polygon(x, y, NUGGET_PX)
        a = 1.0 - smoothstep(-1.5, 1.5, nug)
        if a > 0:
            body = lerp(GOLD_DARK, GOLD, smoothstep(S * 0.80, S * 0.25, y))
            col = lerp(col, body, a)

            # Facets, brightest at the top left where the light is.
            for poly, tone in ((FACET_RIGHT_PX, GOLD_DARK),
                               (FACET_LEFT_PX, GOLD),
                               (FACET_TOP_PX, GOLD_BRIGHT)):
                fa = 1.0 - smoothstep(-1.5, 1.5, sd_polygon(x, y, poly))
                if fa > 0:
                    col = lerp(col, tone, fa * 0.92)

            # A hot specular chip on the top-left facet, so it reads as metal
            # rather than as a flat yellow shape.
            spec = sd_polygon(x, y, scaled([(0.320, 0.300), (0.500, 0.245),
                                            (0.540, 0.360), (0.355, 0.425)]))
            sa_ = 1.0 - smoothstep(-S * 0.055, S * 0.010, spec)
            if sa_ > 0:
                col = lerp(col, GOLD_WHITE, sa_ * sa_ * 0.62)

            # Rim light along the lower right, separating nugget from ground.
            rim = 1.0 - smoothstep(-S * 0.020, 0.0, nug)
            lower_right = smoothstep(S * 0.45, S * 0.75, (x + y) / 2)
            col = lerp(col, GOLD_BRIGHT, rim * lower_right * 0.55)

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
