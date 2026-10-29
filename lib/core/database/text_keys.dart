/// Keys made from user text: grouping keys decide which tracks are the same
/// album or artist, sort keys decide the order. Pure Dart with no Unicode
/// dependency; `text_key_tables.dart` holds the accent data.
///
/// Stored keys are derived from stored text, so changing any rule here means
/// bumping [textKeysVersion]: the library re-keys rows with an older version.
library;

import 'text_key_tables.dart';

/// Version of the rules in this file. Rows keyed with an older version are
/// keyed again. Bump it when a rule changes, and also after a Dart SDK
/// upgrade that changes the output of `toLowerCase`; the recorded-output test
/// in `text_keys_test.dart` fails when that happens. Also bump it when
/// `trackKeysFor` starts writing a new key.
const textKeysVersion = 3;

/// Longest key kept, in characters, so route keys stay bounded even for
/// huge tags.
const maxKeyLength = 256;

/// Identity of a name or title: lower case, NFC, no control or invisible
/// characters, cut to [maxKeyLength]. Accents are kept ("Anh" and "Ánh" are
/// different), but decomposed spellings (macOS tags) equal composed ones.
///
/// Control characters (U+0000–U+001F, U+007F) become spaces: keys must never
/// contain the characters the queries use as delimiters. Invisible format
/// characters (zero-width, direction marks, BOM) are dropped, so they never
/// make a different artist or album. Greek final sigma counts as sigma.
String groupKey(String text) {
  if (_isPlain(text)) return cutKey(text.toLowerCase());
  // Lower case first, so a letter written as base + mark and its precomposed
  // lower-case form end up the same (`J` + U+030C and U+01F0). Dart lower
  // cases U+0130 to a plain `i`, so a dot above after `i` is the same letter.
  final lower = _withoutInvisible(withoutControlChars(text))
      .toLowerCase()
      .replaceAll('\u03c2', '\u03c3')
      .replaceAll('i\u0307', 'i');
  return cutKey(_nfc(lower));
}

/// Order of a name or title: lower case, accents dropped (canonical
/// decomposition without the marks, so "Ánh" sorts beside "Anh"), `đ ð ø ł ß
/// æ œ þ ı` spelled with plain letters, fullwidth ASCII as ASCII, no invisible
/// characters, cut to [maxKeyLength] then trimmed. Other scripts stay in code
/// point order.
String sortKey(String text) {
  if (_isPlain(text)) return cutKey(text.toLowerCase()).trim();
  final runes = <int>[];
  var hasJamo = false;
  final lower = _withoutInvisible(withoutControlChars(text)).toLowerCase();
  for (final rune in lower.runes) {
    if (_isDroppedMark(rune)) continue;
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      runes.add(rune - 0xFEE0); // fullwidth form of an ASCII character
      continue;
    }
    if (rune == 0x3000) {
      runes.add(0x20);
      continue;
    }
    final base = _baseOf(rune);
    final fold = _folds[base];
    if (fold != null) {
      runes.addAll(fold.codeUnits);
    } else {
      if (base >= 0x1100 && base <= 0x11FF) hasJamo = true;
      runes.add(base);
    }
  }
  final composed = hasJamo ? _composeHangul(runes) : runes;
  return cutKey(String.fromCharCodes(composed)).trim();
}

/// [sortKey] for artist and album names, without a leading "the " when
/// something follows it: "The Beatles" sorts under B, "The" alone under T.
String artistSortKey(String name) {
  final key = sortKey(name);
  final the = _leadingThe.firstMatch(key);
  return the == null ? key : key.substring(the.end);
}

/// [text] with control characters (U+0000–U+001F, U+007F) replaced by
/// spaces: tags may hold tabs or NULs.
String withoutControlChars(String text) {
  for (final unit in text.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) {
      return String.fromCharCodes([
        for (final u in text.codeUnits) u < 0x20 || u == 0x7f ? 0x20 : u,
      ]);
    }
  }
  return text;
}

/// [key] cut to [maxKeyLength] characters (not UTF-16 units, so a
/// character is never split).
String cutKey(String key) {
  // Characters never outnumber UTF-16 units: no need to count them.
  if (key.length <= maxKeyLength) return key;
  final runes = key.runes;
  return runes.length <= maxKeyLength
      ? key
      : String.fromCharCodes(runes.take(maxKeyLength));
}

/// Zero-width characters, direction marks and the BOM: no visible effect.
final _invisible = RegExp('[\u200b-\u200f\u202a-\u202e\u2060\ufeff]');

String _withoutInvisible(String text) => text.replaceAll(_invisible, '');

final _leadingThe = RegExp(r'^the\s+(?=\S)');

/// Letters with no canonical decomposition that sort as plain letters.
const _folds = {
  0x111: 'd', // đ
  0xF0: 'd', // ð
  0xF8: 'o', // ø
  0x142: 'l', // ł
  0xDF: 'ss', // ß
  0xE6: 'ae', // æ
  0x153: 'oe', // œ
  0xFE: 'th', // þ
  0x131: 'i', // ı
  0x3C2: '\u03c3', // final sigma
};

/// Precomposed character to (first part, combining mark), one step.
final Map<int, (int, int)> _decompositions = {
  for (var i = 0; i < decompositionTriples.length; i += 3)
    decompositionTriples[i]: (
      decompositionTriples[i + 1],
      decompositionTriples[i + 2],
    ),
};

/// (first part, combining mark) to the precomposed character.
final Map<int, int> _compositions = {
  for (var i = 0; i < decompositionTriples.length; i += 3)
    _pair(decompositionTriples[i + 1], decompositionTriples[i + 2]):
        decompositionTriples[i],
};

final Map<int, int> _markClasses = {
  for (var i = 0; i < markClasses.length; i += 2)
    markClasses[i]: markClasses[i + 1],
};

int _pair(int first, int mark) => first << 21 | mark;

/// Whether every code unit is printable ASCII: nothing to normalize, strip
/// or fold, so the key is the lower-cased text.
bool _isPlain(String text) {
  for (final unit in text.codeUnits) {
    if (unit < 0x20 || unit > 0x7e) return false;
  }
  return true;
}

/// Combining class of [rune]: 0 for starters. Marks outside the table are
/// assumed to sit above the letter (230), the most common class.
int _combiningClass(int rune) =>
    _markClasses[rune] ?? (rune >= 0x300 && rune <= 0x36F ? 230 : 0);

/// Marks that carry no order: combining diacritics and kana voicing marks.
bool _isDroppedMark(int rune) =>
    (rune >= 0x300 && rune <= 0x36F) ||
    (rune >= 0x1AB0 && rune <= 0x1AFF) ||
    (rune >= 0x1DC0 && rune <= 0x1DFF) ||
    (rune >= 0x20D0 && rune <= 0x20FF) ||
    (rune >= 0xFE20 && rune <= 0xFE2F) ||
    rune == 0x3099 ||
    rune == 0x309A;

/// The letter under every accent of [rune]; [rune] itself when plain.
int _baseOf(int rune) {
  var current = rune;
  for (var step = _decompositions[current]; step != null;) {
    current = step.$1;
    step = _decompositions[current];
  }
  return current;
}

/// Whether [text] holds something NFC may change: a combining mark or a
/// Hangul jamo. Precomposed text without them is already in NFC.
bool _needsNfc(String text) {
  for (final unit in text.codeUnits) {
    if ((unit >= 0x300 && unit <= 0x36F) ||
        (unit >= 0x1100 && unit <= 0x11FF) ||
        unit == 0x3099 ||
        unit == 0x309A) {
      return true;
    }
  }
  return false;
}

/// [text] in NFC for the scripts of `text_key_tables.dart` and Hangul;
/// anything else passes through unchanged. Not a full NFC: singletons such as
/// U+212B (Angstrom sign) and marks outside the table are left alone. Case
/// and characters are otherwise kept, so it suits text sent to a service that
/// matches composed spellings only.
String nfcText(String text) => _nfc(text);

/// The implementation of [nfcText] and of [groupKey]'s composing step.
String _nfc(String text) {
  if (!_needsNfc(text)) return text;
  final expanded = <int>[];
  for (final rune in text.runes) {
    _expand(rune, expanded);
  }
  final composed = <int>[];
  var i = 0;
  while (i < expanded.length) {
    var starter = expanded[i++];
    if (_combiningClass(starter) > 0) {
      composed.add(starter); // a mark with nothing to attach to
      continue;
    }
    var end = i;
    while (end < expanded.length && _combiningClass(expanded[end]) > 0) {
      end++;
    }
    final kept = <int>[];
    var lastKeptClass = 0;
    for (final mark in _byCombiningClass(expanded, i, end)) {
      final markClass = _combiningClass(mark);
      final joined = _compositions[_pair(starter, mark)];
      // A mark is blocked by a kept mark of the same or a higher class.
      if (joined != null && lastKeptClass < markClass) {
        starter = joined;
      } else {
        kept.add(mark);
        lastKeptClass = markClass;
      }
    }
    composed
      ..add(starter)
      ..addAll(kept);
    i = end;
  }
  return String.fromCharCodes(_composeHangul(composed));
}

/// Adds [rune] to [out] split into its base letter and marks.
void _expand(int rune, List<int> out) {
  final step = _decompositions[rune];
  if (step == null) {
    out.add(rune);
    return;
  }
  _expand(step.$1, out);
  out.add(step.$2);
}

/// `runes[start:end]` ordered by combining class, keeping the order of marks
/// of the same class (insertion sort: runs are a few marks long).
List<int> _byCombiningClass(List<int> runes, int start, int end) {
  final marks = runes.sublist(start, end);
  for (var i = 1; i < marks.length; i++) {
    final mark = marks[i];
    final markClass = _combiningClass(mark);
    var j = i - 1;
    while (j >= 0 && _combiningClass(marks[j]) > markClass) {
      marks[j + 1] = marks[j];
      j--;
    }
    marks[j + 1] = mark;
  }
  return marks;
}

/// [runes] with Hangul jamo sequences joined into syllables (L+V, then +T).
List<int> _composeHangul(List<int> runes) {
  final out = <int>[];
  for (final rune in runes) {
    if (out.isNotEmpty) {
      final last = out.last;
      if (last >= 0x1100 &&
          last <= 0x1112 &&
          rune >= 0x1161 &&
          rune <= 0x1175) {
        out[out.length - 1] =
            0xAC00 + ((last - 0x1100) * 21 + (rune - 0x1161)) * 28;
        continue;
      }
      if (last >= 0xAC00 &&
          last <= 0xD7A3 &&
          (last - 0xAC00) % 28 == 0 &&
          rune >= 0x11A8 &&
          rune <= 0x11C2) {
        out[out.length - 1] = last + (rune - 0x11A7);
        continue;
      }
    }
    out.add(rune);
  }
  return out;
}
