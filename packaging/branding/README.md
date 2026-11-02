# Kanaru branding

Logo: a white "K" stem and a coral wedge on a dark squircle. This folder tracks the sources that are not already shipped as app icons, plus the colors and the PNG export recipe.

## Colors

| Role | Hex |
| --- | --- |
| Background (squircle) | `#1B1F2A` |
| Stem | `#FFFFFF` |
| Stem on a light background | `#1B1F2A` |
| Wedge | `#FFB4A2` |
| Wedge on a light background | `#D9654A` |
| App theme seed (`kanaruSeedColor`, `lib/app/theme.dart`) | `#FFB4A2` |

## Files

| File | Role |
| --- | --- |
| `../linux/icons/hicolor/scalable/apps/io.github.kanaru313.kanaru.svg` | Master app icon (squircle, rx 30/128). All hicolor PNGs are exported from it. Not duplicated here |
| `../linux/icons/hicolor/symbolic/apps/io.github.kanaru313.kanaru-symbolic.svg` | Single-color `currentColor` glyph for tray and MPRIS. Not duplicated here |
| `svg/kanaru-mark-on-dark.svg` | Glyph only, for dark backgrounds (README, website, splash) |
| `svg/kanaru-mark-on-light.svg` | Glyph only, for light backgrounds (wedge `#D9654A`) |
| `svg/kanaru-avatar-square.svg` | Full-bleed square background, safe when cropped to a circle (GitHub org avatar) |

## Export the hicolor PNGs

Run from the repository root. `rsvg-convert` comes from librsvg (Nix: `nix shell nixpkgs#librsvg`).

```bash
src=packaging/linux/icons/hicolor/scalable/apps/io.github.kanaru313.kanaru.svg
for n in 16 24 32 48 64 128 256 512; do
  rsvg-convert -w $n -h $n "$src" -o packaging/linux/icons/hicolor/${n}x${n}/apps/io.github.kanaru313.kanaru.png
done
```

## Notes

- The wedge is a plain fill path (no stroke), so `.ico`, `.icns` and Android exporters handle it correctly.
- The in-app logo (`lib/shared/widgets/kanaru_logo.dart`) mirrors the scalable app icon SVG with fixed colors. If the logo changes, update that SVG, `kanaru_logo.dart` (its test checks the SVG literals) and the seed color note above together. The symbolic SVG changes on its own.
- Not committed because they are derivable or have no target yet: 1024 px icon and avatar PNGs, raster marks, `favicon.ico`.

## Not made yet

- Trademark and look-alike check: the glyph resembles a "previous track" button (Google Lens, TinEye, WIPO Brand DB).
- The `#1B1F2A` background sinks into dark docks and themes; consider a lighter 1 px edge.
- macOS `.icns`, multi-size Windows `.ico`, Android adaptive icon (66/108 safe zone).
- Wordmark "Kanaru" and a 1280x640 repository social preview image.
