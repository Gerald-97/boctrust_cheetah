"""Builds assets/font/BocIcons.ttf from the bottom nav SVGs.

The nav's Save piggy comes from tdesign, which no icon package ships next to
Vuesax. Packing it into a font lets every IconData slot in the app use it.

Usage (from the repo root):
    python3 -m venv /tmp/boc-icons && /tmp/boc-icons/bin/pip install fonttools picosvg
    /tmp/boc-icons/bin/python tool/icons/build_boc_icons.py

Codepoints must match lib/app/boc_icons.dart.
"""

from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from picosvg.svg import SVG

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/font/BocIcons.ttf"

# Sources are 24x24; scale up so the integer TrueType grid keeps the detail.
VIEWBOX = 24
SCALE = 100
UPM = VIEWBOX * SCALE

GLYPHS = {
    0xE000: ("savings", ROOT / "assets/svg/nav/save_linear.svg"),
    0xE001: ("savings_bold", ROOT / "assets/svg/nav/save_bold.svg"),
}


def draw_glyph(svg_path: Path):
    # picosvg turns strokes into fills and applies transforms and clips, so
    # every shape is a plain filled path in viewBox units.
    pico = SVG.parse(str(svg_path)).topicosvg()
    pen = TTGlyphPen(None)
    # SVG is y-down from the top; fonts are y-up from the baseline.
    flip = TransformPen(Cu2QuPen(pen, max_err=1, reverse_direction=True),
                        (SCALE, 0, 0, -SCALE, 0, UPM))
    for shape in pico.shapes():
        parse_path(shape.as_path().d, flip)
    return pen.glyph()


def main():
    glyph_order = [".notdef"] + [name for name, _ in GLYPHS.values()]
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for name, path in GLYPHS.values():
        glyphs[name] = draw_glyph(path)

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap({cp: name for cp, (name, _) in GLYPHS.items()})
    fb.setupGlyf(glyphs)
    # The left side bearing must equal each glyph's xMin, or renderers shift
    # the outline to start at x = 0.
    glyf = fb.font["glyf"]
    fb.setupHorizontalMetrics({
        name: (UPM, getattr(glyf[name], "xMin", 0)) for name in glyph_order
    })
    # Ascent + descent = UPM, so an Icon's line box is exactly its size.
    fb.setupHorizontalHeader(ascent=UPM, descent=0)
    fb.setupOS2(sTypoAscender=UPM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=UPM, usWinDescent=0)
    fb.setupNameTable({"familyName": "BocIcons", "styleName": "Regular"})
    fb.setupPost()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(OUT))
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
