#!/usr/bin/env python3
"""Generates lib/core/database/text_key_tables.dart from Python's unicodedata.

Needs Python 3.14 (Unicode 16.0.0, the version named in the file header).
Run from the repository root:

    python3 tool/generate_text_key_tables.py > lib/core/database/text_key_tables.dart
    dart format lib/core/database/text_key_tables.dart
"""
import sys
import unicodedata as u

UNICODE_VERSION = '16.0.0'
# Scripts where tags are written with accents: Latin, Greek, Cyrillic,
# Latin Extended Additional, Hiragana and Katakana.
RANGES = [
    (0xC0, 0x24F),
    (0x370, 0x3FF),
    (0x400, 0x4FF),
    (0x1E00, 0x1EFF),
    (0x3040, 0x30FF),
]

if u.unidata_version != UNICODE_VERSION:
    sys.exit(f'Unicode {u.unidata_version}, need {UNICODE_VERSION}: '
             'use Python 3.14')

triples = []  # (precomposed, first part, combining mark)
marks = {}  # combining mark -> canonical combining class
for first, last in RANGES:
    for code in range(first, last + 1):
        decomposition = u.decomposition(chr(code))
        # Compatibility decompositions start with a <tag>; skip them.
        if not decomposition or decomposition.startswith('<'):
            continue
        parts = [int(x, 16) for x in decomposition.split()]
        if len(parts) != 2:
            continue
        # Only pairs that recompose to the character.
        if u.normalize('NFC', chr(parts[0]) + chr(parts[1])) != chr(code):
            continue
        triples.append((code, parts[0], parts[1]))
        marks[parts[1]] = u.combining(chr(parts[1]))


def lines(values, per_line):
    return '\n'.join(
        '  ' + ', '.join('0x%X' % v for v in values[i:i + per_line]) + ','
        for i in range(0, len(values), per_line))


flat_triples = [x for triple in triples for x in triple]
flat_marks = [x for mark, cls in sorted(marks.items()) for x in (mark, cls)]
print(f"""/// Canonical decompositions for the scripts where tags are written with
/// accents, and the combining-mark classes needed to put marks in canonical
/// order. Backs `text_keys.dart` without a Unicode dependency.
///
/// Generated from Unicode {u.unidata_version} by `tool/generate_text_key_tables.py`:
/// every two-part canonical decomposition that recomposes, for U+00C0-U+024F,
/// U+0370-U+03FF, U+0400-U+04FF, U+1E00-U+1EFF and U+3040-U+30FF. Do not edit
/// by hand.
library;

/// Flat triples: precomposed character, first part, combining mark. A first
/// part may itself be precomposed (U+1EAD = U+1EA1 + U+0302).
const decompositionTriples = <int>[
{lines(flat_triples, 9)}
];

/// Flat pairs: combining mark, canonical combining class, for every mark in
/// [decompositionTriples].
const markClasses = <int>[
{lines(flat_marks, 10)}
];""")
