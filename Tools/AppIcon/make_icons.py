#!/usr/bin/env python3
"""Just Shikaku app icon — "Lacquered Measure" (see PHILOSOPHY.md).

The mark is still a valid clue: a 2x2 mat holding a "4", set into a lacquered
room whose incised lines complete a real partition. One luminous field against
warm darkness; texture that reads as fabric at arm's length and as a single
confident color from across the room.

Do not hand-edit the PNGs; re-run this script. Check the 40pt proof before
committing — an icon that only works at 1024 is not an icon.

    python3 Tools/AppIcon/make_icons.py            # renders the icon + proofs
    python3 Tools/AppIcon/make_icons.py candidates # renders A/B/C to /tmp
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
SCALE = 4
R = S * SCALE

FONTS = os.path.expanduser("~/.claude/skills/canvas-design/canvas-fonts")

# Lacquer ground
LACQ_EDGE = (24, 19, 13)
LACQ_MID = (43, 35, 24)
INCISED = (66, 55, 38)

# The mat
IGUSA_LIGHT = (154, 171, 122)
IGUSA_DEEP = (108, 126, 86)
WEAVE_DARK = (96, 113, 76)
HERI = (40, 50, 34)
STITCH = (168, 142, 88)

CREAM = (242, 235, 216)


def s(v):
    return int(v * SCALE)


def lacquer_ground(draw):
    """Radial warmth: lacquer brightening toward the upper third, the way a
    surface warms under a lamp. Painted as concentric blends, then grained."""
    cx, cy = R * 0.42, R * 0.36
    maxd = math.hypot(R, R)
    for y in range(0, R, 2):
        for band_x in range(0, R, R // 8):
            pass
    # Row-wise interpolation against distance from the lamp point.
    for y in range(R):
        # sample a few x positions per row and interpolate linearly
        row = []
        for x in (0, R // 4, R // 2, 3 * R // 4, R - 1):
            d = math.hypot(x - cx, y - cy) / maxd
            t = min(1.0, d * 1.35)
            c = tuple(int(LACQ_MID[i] + (LACQ_EDGE[i] - LACQ_MID[i]) * t) for i in range(3))
            row.append((x, c))
        for i in range(len(row) - 1):
            x0, c0 = row[i]
            x1, c1 = row[i + 1]
            for x in range(x0, x1 + 1):
                f = (x - x0) / max(1, x1 - x0)
                draw.point((x, y), tuple(int(c0[j] + (c1[j] - c0[j]) * f) for j in range(3)))


def lacquer_ground_fast(image):
    """Radial warm gradient via small-scale render + resize (fast, smooth)."""
    small = 128
    img = Image.new("RGB", (small, small))
    px = img.load()
    cx, cy = small * 0.42, small * 0.34
    maxd = math.hypot(small, small) * 0.72
    for y in range(small):
        for x in range(small):
            d = math.hypot(x - cx, y - cy) / maxd
            t = min(1.0, d)
            t = t * t * (3 - 2 * t)  # smoothstep
            px[x, y] = tuple(int(LACQ_MID[i] + (LACQ_EDGE[i] - LACQ_MID[i]) * t)
                             for i in range(3))
    image.paste(img.resize((R, R), Image.BICUBIC))


def grain(image, amount=5, seed=7):
    """Fine lacquer grain: low-amplitude noise, softened."""
    rnd = random.Random(seed)
    noise = Image.new("L", (R // 4, R // 4))
    px = noise.load()
    for y in range(R // 4):
        for x in range(R // 4):
            px[x, y] = 128 + rnd.randint(-amount, amount)
    noise = noise.resize((R, R), Image.BILINEAR)
    flat = Image.new("L", (R, R), 128)
    image.paste(Image.composite(
        Image.eval(image, lambda v: min(255, v + 6)),
        Image.eval(image, lambda v: max(0, v - 6)),
        Image.eval(noise, lambda v: 255 if v > 128 else 0)
    ), (0, 0), Image.eval(noise, lambda v: abs(v - 128) * 10))
    return image


def incised_partition(draw, faint_font=None):
    """The whole icon is a solved 3x3 room: the 2x2 mat (the 4), a 1x3 right
    column (a 3), and a 2x1 bottom strip (a 2). Incised as faint grooves;
    the neighbours' numerals sit at whisper level - invisible at 40pt,
    rewarding at arm's length."""
    inset = s(64)
    u = (R - 2 * inset) // 3
    x0 = y0 = inset
    x1 = x0 + 3 * u
    y1 = y0 + 3 * u
    w = s(7)

    draw.rectangle([x0, y0, x1, y1], outline=INCISED, width=w)
    draw.line([(x0 + 2 * u, y0), (x0 + 2 * u, y1)], fill=INCISED, width=w)
    draw.line([(x0, y0 + 2 * u), (x0 + 2 * u, y0 + 2 * u)], fill=INCISED, width=w)

    if faint_font:
        for glyph, cx, cy in (("3", x0 + 2 * u + u // 2, y0 + u + u // 2),
                              ("2", x0 + u, y0 + 2 * u + u // 2)):
            font = ImageFont.truetype(faint_font, size=s(72))
            bbox = draw.textbbox((0, 0), glyph, font=font)
            gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
            draw.text((cx - gw / 2 - bbox[0], cy - gh / 2 - bbox[1]),
                      glyph, font=font, fill=INCISED)
    return inset, u


def weave(tile_draw, rect, direction, seed=3):
    """Rush weave: fine parallel threads with per-thread jitter, contrast one
    step before obviousness. direction: 'h' threads run horizontally."""
    rnd = random.Random(seed)
    x0, y0, x1, y1 = rect
    pitch = s(7)
    if direction == "h":
        y = y0 + pitch
        while y < y1 - pitch // 2:
            alpha = rnd.randint(14, 30)
            tile_draw.line([(x0 + s(6), y), (x1 - s(6), y)],
                           fill=WEAVE_DARK + (alpha,), width=max(1, s(1.4)))
            y += pitch
    else:
        x = x0 + pitch
        while x < x1 - pitch // 2:
            alpha = rnd.randint(14, 30)
            tile_draw.line([(x, y0 + s(6)), (x, y1 - s(6))],
                           fill=WEAVE_DARK + (alpha,), width=max(1, s(1.4)))
            x += pitch


def mat(image, rect, glyph_font_path, glyph="4", glyph_scale=0.62):
    """The luminous field: igusa gradient, weave, heri edge with gold
    stitching, and the glyph pressed like a seal."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0

    # Igusa gradient (diagonal, light falls from upper left).
    grad = Image.new("RGB", (256, 256))
    gpx = grad.load()
    for gy in range(256):
        for gx in range(256):
            t = min(1.0, (gx / 255 * 0.45 + gy / 255 * 0.55))
            gpx[gx, gy] = tuple(int(IGUSA_LIGHT[i] + (IGUSA_DEEP[i] - IGUSA_LIGHT[i]) * t)
                                for i in range(3))
    image.paste(grad.resize((w, h), Image.BICUBIC), (x0, y0))

    # Weave threads.
    overlay = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    weave(odraw, rect, "h")
    image.paste(Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB"), (0, 0))

    draw = ImageDraw.Draw(image)

    # Heri: the woven edge band, with gold stitch rhythm.
    band = s(30)
    draw.rectangle([x0, y0, x1, y1], outline=HERI, width=band)
    stitch_len, gap = s(26), s(30)
    inset = band // 2
    for edge in range(4):
        if edge in (0, 2):   # top, bottom
            y = y0 + inset if edge == 0 else y1 - inset
            x = x0 + s(36)
            while x < x1 - s(36):
                draw.line([(x, y), (min(x + stitch_len, x1 - s(36)), y)],
                          fill=STITCH, width=s(2.6))
                x += stitch_len + gap
        else:                # left, right
            x = x0 + inset if edge == 1 else x1 - inset
            y = y0 + s(36)
            while y < y1 - s(36):
                draw.line([(x, y), (x, min(y + stitch_len, y1 - s(36)))],
                          fill=STITCH, width=s(2.6))
                y += stitch_len + gap

    # The glyph, sized by cap height, optically centered.
    target_cap = int(h * glyph_scale)
    size = target_cap
    for _ in range(12):
        font = ImageFont.truetype(glyph_font_path, size=size)
        bbox = draw.textbbox((0, 0), glyph, font=font)
        cap = bbox[3] - bbox[1]
        if abs(cap - target_cap) <= s(4):
            break
        size = int(size * target_cap / max(cap, 1))
    bbox = draw.textbbox((0, 0), glyph, font=font)
    gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2 - s(6)
    # Pressed-seal depth: a whisper of darker green under the cream — one
    # tight step, not a cast shadow (the system owns lighting; a heavy offset
    # reads as baked-in gloss).
    draw.text((cx - gw / 2 - bbox[0] + s(2.5), cy - gh / 2 - bbox[1] + s(3.5)),
              glyph, font=font, fill=(88, 103, 70))
    draw.text((cx - gw / 2 - bbox[0], cy - gh / 2 - bbox[1]),
              glyph, font=font, fill=CREAM)


def render(font_name, out, faint_numerals=True):
    image = Image.new("RGB", (R, R))
    lacquer_ground_fast(image)
    draw = ImageDraw.Draw(image)
    font_path = os.path.join(FONTS, font_name)
    inset, u = incised_partition(draw, faint_font=font_path if faint_numerals else None)
    mat_rect = (inset, inset, inset + 2 * u, inset + 2 * u)
    mat(image, mat_rect, font_path)
    image = grain(image)
    final = image.resize((S, S), Image.LANCZOS)
    final.save(out)
    final.resize((180, 180), Image.LANCZOS).save(out.replace(".png", "-180.png"))
    final.resize((120, 120), Image.LANCZOS).save(out.replace(".png", "-120.png"))
    print("wrote", out)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "candidates":
        render("YoungSerif-Regular.ttf", "/tmp/icon_A_youngserif.png")
        render("YoungSerif-Regular.ttf", "/tmp/icon_A2_nonumerals.png", faint_numerals=False)
        render("BigShoulders-Bold.ttf", "/tmp/icon_B_bigshoulders.png")
        render("Boldonse-Regular.ttf", "/tmp/icon_C_boldonse.png")
        return
    out = "Shikaku/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    render("YoungSerif-Regular.ttf", out)
    # Proofs land next to /tmp for review, never in the asset catalog.
    img = Image.open(out)
    img.resize((120, 120), Image.LANCZOS).save("/tmp/shikaku_icon_40pt.png")
    for extra in (out.replace(".png", "-180.png"), out.replace(".png", "-120.png")):
        if os.path.exists(extra):
            os.remove(extra)
    print("wrote /tmp/shikaku_icon_40pt.png (40pt @3x proof)")


if __name__ == "__main__":
    main()
