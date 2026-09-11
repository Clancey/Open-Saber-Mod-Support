"""Bitmap (BMFont) atlases for the Open Saber UI, rendered from the Teko
typeface by Indian Type Foundry under the SIL Open Font License 1.1.

The game draws its 3D labels with Label3D/TextMesh, which want a BMFont page
rather than a live TTF, so each weight is rasterised here into a single 1024
atlas plus the matching .fnt metrics. The source is the upstream OFL release of
Teko (tools/art/Teko-Variable.ttf); the licence travels with the atlases in
game/ui/fonts/OFL.txt.

Run:  python3 tools/art/gen_fonts.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "Teko-Variable.ttf")
OUT = os.path.join(ROOT, "game", "ui", "fonts")

SIZE = 89          # px em size the UI was laid out against
ATLAS = 1024
LINE_HEIGHT = 128  # kept from the previous atlases so nothing shifts
BASE = 85
PAD = 2            # transparent gutter so neighbours never bleed

# The glyphs the UI needs: ASCII plus the Latin-1/European accents and the
# punctuation that shows up in song titles and mapper names.
RANGES = [
    (32, 93), (95, 123), (125, 126), (160, 163), (165, 165), (167, 167),
    (169, 169), (171, 171), (176, 176), (187, 187), (191, 194), (196, 202),
    (205, 206), (209, 209), (211, 214), (217, 220), (223, 229), (231, 234),
    (237, 238), (241, 241), (243, 244), (246, 246), (249, 253), (258, 259),
    (268, 269), (283, 283), (328, 328), (338, 339), (345, 345), (352, 353),
    (537, 537), (8211, 8212), (8216, 8217), (8220, 8222), (8224, 8225),
    (8230, 8230), (8482, 8482), (8729, 8729),
]

WEIGHTS = [("teko_medium", 500), ("teko_bold", 700)]


def charset():
    out = []
    for lo, hi in RANGES:
        out.extend(range(lo, hi + 1))
    return sorted(set(out))


def render_glyph(font, ch, ascent):
    """Draw one glyph on its own and return (image, xoffset, yoffset, xadvance).

    The scratch canvas puts the pen at PAD and the baseline at PAD + ascent, so
    the inked box can be measured straight off it.
    """
    advance = font.getlength(ch)
    w = max(int(advance) + PAD * 4, 4)
    h = ascent + font.getmetrics()[1] + PAD * 4
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).text((PAD, PAD + ascent), ch, font=font, fill=255, anchor="ls")
    box = img.getbbox()
    if box is None:                       # whitespace
        return None, 0, 0, int(round(advance))
    x0, y0, x1, y1 = box
    return (
        img.crop(box),
        x0 - PAD,
        BASE + y0 - (PAD + ascent),
        int(round(advance)),
    )


def build(name, weight):
    font = ImageFont.truetype(SRC, SIZE)
    font.set_variation_by_axes([weight])
    ascent = font.getmetrics()[0]

    glyphs = []
    for cp in charset():
        img, xo, yo, adv = render_glyph(font, chr(cp), ascent)
        glyphs.append((cp, img, xo, yo, adv))

    # Shelf-pack the inked glyphs, tallest first so the rows stay tight.
    inked = sorted(
        [g for g in glyphs if g[1] is not None], key=lambda g: -g[1].height
    )
    page = Image.new("L", (ATLAS, ATLAS), 0)
    place = {}
    x = y = row = 0
    for cp, img, _xo, _yo, _adv in inked:
        if x + img.width + PAD > ATLAS:
            x = 0
            y += row + PAD
            row = 0
        if y + img.height > ATLAS:
            raise SystemExit("%s: glyphs overflow a %dpx atlas" % (name, ATLAS))
        page.paste(img, (x, y))
        place[cp] = (x, y, img.width, img.height)
        x += img.width + PAD
        row = max(row, img.height)

    rgba = Image.merge("RGBA", (
        Image.new("L", page.size, 255), Image.new("L", page.size, 255),
        Image.new("L", page.size, 255), page,
    ))
    os.makedirs(OUT, exist_ok=True)
    rgba.save(os.path.join(OUT, name + ".png"))

    face = "Teko %s" % ("Bold" if weight >= 700 else "Medium")
    lines = [
        'info face="%s" size=%d bold=%d italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0 outline=0'
        % (face, SIZE, 1 if weight >= 700 else 0),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"
        % (LINE_HEIGHT, BASE, ATLAS, ATLAS),
        'page id=0 file="%s.png"' % name,
        "chars count=%d" % len(glyphs),
    ]
    for cp, img, xo, yo, adv in glyphs:
        gx, gy, gw, gh = place.get(cp, (0, 0, 0, 0))
        if img is None:
            xo = yo = 0
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d "
            "xadvance=%d page=0 chnl=15" % (cp, gx, gy, gw, gh, xo, yo, adv)
        )
    lines.append("kernings count=0")
    with open(os.path.join(OUT, name + ".fnt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return len(glyphs), max((p[1] + p[3]) for p in place.values())


def main():
    if not os.path.exists(SRC):
        raise SystemExit("missing %s - fetch the OFL release of Teko first" % SRC)
    for name, weight in WEIGHTS:
        n, used = build(name, weight)
        print("%s: %d glyphs, atlas rows used %d/%d" % (name, n, used, ATLAS))


if __name__ == "__main__":
    main()
