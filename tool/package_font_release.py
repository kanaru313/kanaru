#!/usr/bin/env python3
"""
Package font sources into flat release zips and print manifest values.

Layout:  tool/font_sources/<id>/{*.ttf|*.otf, OFL.txt | LICENSE.txt}
Usage:   python tool/package_font_release.py tool/font_sources/* -o build/fonts-v1
Needs:   pip install fonttools
"""
import argparse
import hashlib
import sys
import zipfile
from pathlib import Path

from fontTools.ttLib import TTFont

FONT_EXT = {".ttf", ".otf"}
LICENSE_NAMES = {"ofl.txt", "license.txt", "license"}
VIETNAMESE = "ĂÂÊÔƠƯĐăâêôơưđẮỀỔỮỰ"
FIXED_DATE = (2020, 1, 1, 0, 0, 0)  # reproducible output


def package(src: Path, out_dir: Path):
    files = [p for p in src.iterdir() if p.is_file()]  # top level only => flat
    fonts = sorted(p for p in files if p.suffix.lower() in FONT_EXT)
    licenses = sorted(p for p in files if p.name.lower() in LICENSE_NAMES)

    if not fonts:
        raise SystemExit(f"{src.name}: no .ttf/.otf files")
    if not licenses:
        raise SystemExit(f"{src.name}: missing OFL.txt / LICENSE.txt")
    for p in fonts:
        if "variable" in p.name.lower() or "[" in p.name:
            raise SystemExit(f"{src.name}: variable font not allowed: {p.name}")

    cmap = TTFont(fonts[0]).getBestCmap()
    missing = [c for c in VIETNAMESE if ord(c) not in cmap]
    if missing:
        print(
            f"warning: {src.name}: {fonts[0].name} lacks {''.join(missing)}",
            file=sys.stderr,
        )

    out = out_dir / f"{src.name}.zip"
    with zipfile.ZipFile(out, "w") as z:
        for p in [*fonts, *licenses]:
            info = zipfile.ZipInfo(p.name, date_time=FIXED_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes())

    data = out.read_bytes()
    return out.name, len(data), hashlib.sha256(data).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sources", nargs="+", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=Path("build/fonts-v1"))
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    for src in args.sources:
        if src.is_dir():
            name, size, digest = package(src, args.out)
            print(f"{src.name}: filename={name} sizeBytes={size} sha256={digest}")


if __name__ == "__main__":
    main()
