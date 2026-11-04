#!/usr/bin/env python3
"""
Generate lightweight SVG vector previews for fonts (font name + one sample line).

Output uses fill="currentColor", so the UI can tint it with the current theme.

Install:
    pip install fonttools uharfbuzz

Usage:
    python tool/gen_font_preview.py assets/fonts/*.ttf -o assets/font_previews
"""
import argparse
import re
import sys
from pathlib import Path

from fontTools.pens.boundsPen import ControlBoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

try:
    import uharfbuzz as hb
except ImportError:
    hb = None

# Compact representative sample text
SAMPLE_TEXT = "Aa Bb Cc Gg Qq Rr Yy 0123456789"

# Layout metrics (logical px)
TITLE_SIZE = 16
SAMPLE_SIZE = 14
PAD = 0
TITLE_BASELINE = 17
SAMPLE_BASELINE = 35
HEIGHT = 44
SAMPLE_OPACITY = 0.65


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def shape(text, tt, hbfont):
    """Calculate glyph positions and kerning."""
    if hbfont is not None:
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(hbfont, buf)
        return [
            (tt.getGlyphName(i.codepoint), p.x_advance, p.x_offset, p.y_offset)
            for i, p in zip(buf.glyph_infos, buf.glyph_positions)
        ]
    cmap = tt.getBestCmap()
    hmtx = tt["hmtx"]
    out = []
    for ch in text:
        name = cmap.get(ord(ch))
        if name:
            out.append((name, hmtx[name][0], 0, 0))
    return out


def draw_line(text, size, tt, hbfont):
    glyphset = tt.getGlyphSet()
    scale = size / tt["head"].unitsPerEm
    rec = RecordingPen()
    x = 0
    for name, adv, xo, yo in shape(text, tt, hbfont):
        matrix = (scale, 0, 0, -scale, (x + xo) * scale, -yo * scale)
        glyphset[name].draw(TransformPen(rec, matrix))
        x += adv
    return rec, x * scale


def path_data(rec, dx, dy, glyphset):
    pen = SVGPathPen(glyphset, ntos=lambda v: f"{round(v, 1):g}")
    rec.replay(TransformPen(pen, (1, 0, 0, 1, dx, dy)))
    return pen.getCommands()


def top_of(rec, dy, glyphset):
    bp = ControlBoundsPen(glyphset)
    rec.replay(bp)
    return dy + bp.bounds[1] if bp.bounds else dy


def build_svg(font_path: Path):
    tt = TTFont(font_path, fontNumber=0)
    glyphset = tt.getGlyphSet()
    hbfont = None
    if hb is not None:
        hbfont = hb.Font(hb.Face(hb.Blob.from_file_path(str(font_path))))

    family = tt["name"].getBestFamilyName() or font_path.stem

    title_rec, w1 = draw_line(family, TITLE_SIZE, tt, hbfont)
    sample_rec, w2 = draw_line(SAMPLE_TEXT, SAMPLE_SIZE, tt, hbfont)

    width = max(w1, w2) + PAD * 2
    min_y = min(0.0, top_of(title_rec, TITLE_BASELINE, glyphset) - 4,
                top_of(sample_rec, SAMPLE_BASELINE, glyphset) - 4)

    d1 = path_data(title_rec, PAD, TITLE_BASELINE, glyphset)
    d2 = path_data(sample_rec, PAD, SAMPLE_BASELINE, glyphset)
    vb_h = HEIGHT - min_y

    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 {min_y:g} {width:.0f} {vb_h:.0f}" '
        f'preserveAspectRatio="xMinYMid meet">\n'
        f'  <path fill="currentColor" d="{d1}"/>\n'
        f'  <path fill="currentColor" fill-opacity="{SAMPLE_OPACITY}" d="{d2}"/>\n'
        f'</svg>\n'
    )
    return slugify(family), svg


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("fonts", nargs="+", type=Path, help="Font file paths (.ttf/.otf)")
    ap.add_argument("-o", "--out", type=Path, default=Path("assets/font_previews"), help="Output directory")
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    for font_path in args.fonts:
        try:
            font_id, svg = build_svg(font_path)
            out_file = args.out / f"{font_id}.svg"
            out_file.write_text(svg, encoding="utf-8")
            print(f"✓ {font_id} -> {out_file} ({out_file.stat().st_size / 1024:.1f} KB)")
        except Exception as e:
            print(f"✗ {font_path}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
