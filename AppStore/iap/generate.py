#!/usr/bin/env python3
"""In-app purchase artwork for Just Shikaku.

    python3 AppStore/iap/generate.py

Writes two files next to this script:

  shikaku-full.png                 1024x1024 promotional image
  review-screenshot-2048x2732.png  2048x2732 IAP review screenshot

Both are the rules lesson's board, solved: a 3x3 room partitioned into three
mats (a 1, a 2 and a 6), so the image is a true statement about the game in
the game's own materials. Palette from Theme.swift / Tools/AppIcon/make_icons.py.

RGB with no alpha: App Store artwork with transparency is rejected under
ITMS-90717. The review screenshot must be exactly 2048x2732 or it is refused
with "the dimensions of one or more screenshots are wrong".
"""

import os
from PIL import Image, ImageDraw, ImageFont

STRAW = (239, 233, 218)   # straw-paper floor
INK = (38, 35, 28)        # sumi ink
MAT = (200, 209, 183)     # igusa wash flattened onto straw
HERI = (62, 74, 53)       # the mat's woven edge band

LABEL_TEXT = "Every lesson, drill and hint"

MENLO = "/System/Library/Fonts/Menlo.ttc"

# The rules lesson board, solved: three mats tile the 3x3 room.
# c0,r0..c1,r1 are inclusive cell ranges; "cc" is the cell holding the clue.
MATS = [
    {"c0": 0, "r0": 0, "c1": 0, "r1": 0, "clue": 1, "cc": (0, 0)},
    {"c0": 1, "r0": 0, "c1": 2, "r1": 0, "clue": 2, "cc": (2, 0)},
    {"c0": 0, "r0": 1, "c1": 2, "r1": 2, "clue": 6, "cc": (0, 2)},
]
COLS = ROWS = 3


def menlo(size, bold=False):
    """Menlo from the ttc, by face rather than by guessed index."""
    want = "Bold" if bold else "Regular"
    for index in range(4):
        try:
            f = ImageFont.truetype(MENLO, size=int(size), index=index)
        except OSError:
            break
        if f.getname()[1] == want:
            return f
    raise SystemExit(f"Menlo {want} not found in {MENLO}")


def menlo_for_cap(draw, target_cap, sample="6", bold=False):
    """Size a numeral by cap height, the icon script's approach: nominal point
    size lies, the measured glyph box does not."""
    size = target_cap
    f = menlo(size, bold)
    for _ in range(12):
        f = menlo(size, bold)
        box = draw.textbbox((0, 0), sample, font=f)
        cap = box[3] - box[1]
        if abs(cap - target_cap) <= max(2, target_cap // 80):
            return f
        size = int(size * target_cap / max(cap, 1))
    return f


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_text_centered(draw, cx, cy, text, font, fill):
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text((cx - w / 2 - box[0], cy - h / 2 - box[1]), text, font=font, fill=fill)


def draw_board(draw, ox, oy, cell, scale):
    """The solved rules board. All arguments in render pixels except `cell`
    and the offsets, which are already scaled by the caller."""
    heri_w = int(12 * scale)
    frame_w = int(10 * scale)
    weave_w = max(2, int(3 * scale))
    weave_inset = int(34 * scale)
    weave_step = int(40 * scale)
    weave_ink = mix(MAT, HERI, 0.5)

    for mat in MATS:
        x0 = ox + mat["c0"] * cell
        y0 = oy + mat["r0"] * cell
        x1 = ox + (mat["c1"] + 1) * cell
        y1 = oy + (mat["r1"] + 1) * cell

        draw.rectangle([x0, y0, x1, y1], fill=MAT)

        # The clue cell stays plain straw-on-mat so the numeral sits on a
        # quiet field: weave lines part around it rather than being patched
        # over, which would leave stubs.
        ccx0 = ox + mat["cc"][0] * cell
        ccy0 = oy + mat["cc"][1] * cell
        ccx1, ccy1 = ccx0 + cell, ccy0 + cell

        def spans(lo, hi, cut_lo, cut_hi, cut):
            if not cut:
                return [(lo, hi)]
            out = []
            if cut_lo - lo > weave_step:
                out.append((lo, cut_lo))
            if hi - cut_hi > weave_step:
                out.append((cut_hi, hi))
            return out

        # Weave lines run along the mat's long axis. A square mat has no long
        # axis, so the 1x1 stays plain.
        w_cells = mat["c1"] - mat["c0"] + 1
        h_cells = mat["r1"] - mat["r0"] + 1
        if w_cells != h_cells or w_cells > 1:
            if w_cells >= h_cells:
                y = y0 + weave_inset + weave_step
                while y < y1 - weave_inset:
                    for sx0, sx1 in spans(x0 + weave_inset, x1 - weave_inset,
                                          ccx0, ccx1, ccy0 < y < ccy1):
                        draw.line([(sx0, y), (sx1, y)], fill=weave_ink, width=weave_w)
                    y += weave_step
            else:
                x = x0 + weave_inset + weave_step
                while x < x1 - weave_inset:
                    for sy0, sy1 in spans(y0 + weave_inset, y1 - weave_inset,
                                          ccy0, ccy1, ccx0 < x < ccx1):
                        draw.line([(x, sy0), (x, sy1)], fill=weave_ink, width=weave_w)
                    x += weave_step

        draw.rectangle([x0, y0, x1, y1], outline=HERI, width=heri_w)

    # The room's outer ink frame, over the mats' edges.
    draw.rectangle([ox, oy, ox + COLS * cell, oy + ROWS * cell],
                   outline=INK, width=frame_w)

    # Clue numerals, sized by cap height, centred in their cells.
    digit_font = menlo_for_cap(draw, int(cell * 0.42))
    for mat in MATS:
        col, row = mat["cc"]
        cx = ox + col * cell + cell // 2
        cy = oy + row * cell + cell // 2
        draw_text_centered(draw, cx, cy, str(mat["clue"]), digit_font, INK)


def make_promo(out_dir):
    SIZE, SCALE = 1024, 4
    render = SIZE * SCALE
    image = Image.new("RGB", (render, render), STRAW)
    draw = ImageDraw.Draw(image)

    cell = 225 * SCALE
    ox = (render - COLS * cell) // 2
    oy = (render - ROWS * cell) // 2 - 46 * SCALE   # room for one line below
    draw_board(draw, ox, oy, cell, SCALE)

    label_font = menlo_for_cap(draw, 33 * SCALE, sample="E")
    draw_text_centered(draw, render / 2, (SIZE - 120) * SCALE,
                       LABEL_TEXT, label_font, INK)

    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    out = os.path.join(out_dir, "shikaku-full.png")
    image.save(out)          # RGB, no alpha
    return out


def make_screenshot(out_dir):
    W, H, SCALE = 2048, 2732, 2
    rw, rh = W * SCALE, H * SCALE
    image = Image.new("RGB", (rw, rh), STRAW)
    draw = ImageDraw.Draw(image)

    title_font = menlo_for_cap(draw, 110 * SCALE, sample="J", bold=True)
    draw_text_centered(draw, rw / 2, 420 * SCALE, "Just Shikaku", title_font, INK)

    cell = 380 * SCALE
    ox = (rw - COLS * cell) // 2
    oy = (rh - ROWS * cell) // 2 - 60 * SCALE
    draw_board(draw, ox, oy, cell, SCALE)

    sub_font = menlo_for_cap(draw, 46 * SCALE, sample="S")
    draw_text_centered(draw, rw / 2, 2180 * SCALE,
                       "Shikaku Full — one purchase, forever", sub_font, INK)
    label_font = menlo_for_cap(draw, 34 * SCALE, sample="E")
    draw_text_centered(draw, rw / 2, 2290 * SCALE,
                       LABEL_TEXT, label_font, mix(STRAW, INK, 0.72))

    image = image.resize((W, H), Image.LANCZOS)
    out = os.path.join(out_dir, "review-screenshot-2048x2732.png")
    image.save(out)          # RGB, no alpha
    return out


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    for out in (make_promo(out_dir), make_screenshot(out_dir)):
        check = Image.open(out)
        print(f"wrote {out}  {check.size} {check.mode}  {os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main()
