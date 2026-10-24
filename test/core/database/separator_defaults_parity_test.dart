// The splitting code as it was before the separators became rules, copied
// here as the oracle: the rules it was written for must give its results for
// every input. Do not "fix" it; a change in behaviour belongs in the rules tests.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/core/database/genre_names.dart';
import 'package:kanaru/core/database/text_keys.dart';

/// The artist separators before the defaults gained `,` and `//` (and lost
/// `/`). The oracle matches them, so these rules must give its results.
const _oldArtistRules = SplitRules(
  separators: [';', '/', 'feat.', 'feat', 'ft.', 'ft', 'featuring', 'with'],
  keepWhole: ['AC/DC'],
);

/// Names containing `/` that are one artist, lower-cased. Matched only as
/// whole names: `Shellac/DC Talk` still splits.
const _oracleSlashExceptions = {'ac/dc'};

/// `feat.`, `ft.` (dot optional), `featuring`, `with`.
const _oracleFeaturing = r'(?:feat\.?|ft\.?|featuring|with)';

/// `A (feat. B)` or `A [ft. B]`: the bracketed part becomes a plain name.
final _oracleBracketed = RegExp(
  '\\s*[(\\[]\\s*$_oracleFeaturing\\s+([^)\\]]*)[)\\]]',
  caseSensitive: false,
);

/// `;` with any spacing, or a featuring word with whitespace on each side.
final _oracleSeparator = RegExp(
  '\\s*;\\s*|\\s+$_oracleFeaturing\\s+',
  caseSensitive: false,
);

/// Whitespace followed by the first letter of a featuring word: the cheap
/// test of whether [_separator] may match.
final _oracleMaybeFeaturing = RegExp(r'\s[fw]', caseSensitive: false);

/// How many `/`-separated pieces each exception spans, longest first.
final _oracleSpans = {
  for (final name in _oracleSlashExceptions) name.split('/').length,
}.toList()..sort((a, b) => b - a);

/// The artist names in an `artist` or `album_artist` tag, in order, trimmed,
/// without empty parts and without repeats (compared by [artistKey], so `Beyoncé` spelled with a
/// combining accent is the same artist, while `Anh` and `Ánh` are two).
///
/// Splits on `;` (however spaced), ` feat. `, ` ft. `, ` featuring `,
/// ` with ` (any case, dot optional, any whitespace around) and `/`, except
/// in names of [_oracleSlashExceptions] such as `AC/DC`. A bracketed featuring
/// part (`A (feat. B)`) gives its names too. Never splits on `,` or `&`,
/// which are often part of one name. Control characters count as spaces.
List<String> oracleSplitArtists(String? tag) {
  if (tag == null || tag.isEmpty) return const [];
  var text = withoutControlChars(tag);
  // Most tags name one artist; skip the regular expressions for them.
  if (!_oracleMayHoldSeveral(text)) {
    final name = text.trim();
    return name.isEmpty ? const [] : [name];
  }
  if (text.contains('(') || text.contains('[')) {
    text = text.replaceAllMapped(_oracleBracketed, (m) => '; ${m[1]}');
  }

  final names = <String>[];
  final keys = <String>{};
  for (final part in text.split(_oracleSeparator)) {
    for (final piece in _oracleSplitSlashes(part)) {
      final name = piece.trim();
      if (name.isNotEmpty && keys.add(artistKey(name))) names.add(name);
    }
  }
  return names;
}

/// [part] split on `/`, keeping runs of pieces that form an exception.
List<String> _oracleSplitSlashes(String part) {
  final pieces = part.split('/');
  if (pieces.length == 1) return pieces;
  final out = <String>[];
  var i = 0;
  next:
  while (i < pieces.length) {
    for (final span in _oracleSpans) {
      if (span < 2 || i + span > pieces.length) continue;
      final joined = pieces.sublist(i, i + span).join('/');
      if (_oracleSlashExceptions.contains(joined.trim().toLowerCase())) {
        out.add(joined);
        i += span;
        continue next;
      }
    }
    out.add(pieces[i++]);
  }
  return out;
}

/// Whether [tag] has something that may separate names: `;`, `/`, a
/// bracket, or a featuring word after whitespace. A cheap check before the
/// regular expressions, which cost far more per tag.
bool _oracleMayHoldSeveral(String tag) =>
    tag.contains(';') ||
    tag.contains('/') ||
    tag.contains('(') ||
    tag.contains('[') ||
    tag.contains(_oracleMaybeFeaturing);

final _oracleGenrePatterns = <String, RegExp>{};

/// One pattern per distinct list of separators, made on first use.
RegExp _oracleGenrePattern(List<String> separators) =>
    _oracleGenrePatterns.putIfAbsent(
      separators.join('\u0000'),
      () => RegExp('\\s*(?:${separators.map(RegExp.escape).join('|')})\\s*'),
    );

/// The genres named in a stored genre string: split on any of [separators]
/// (empty entries ignored), trimmed, without empty parts, and without
/// repeats by [genreKey] (the first spelling stays). Empty for null.
List<String> oracleSplitGenres(
  String? tag, {
  List<String> separators = const [';'],
}) {
  if (tag == null) return const [];
  final parts = separators.isEmpty || separators.every((s) => s.isEmpty)
      ? [tag]
      : tag.split(
          _oracleGenrePattern([
            for (final s in separators)
              if (s.isNotEmpty) s,
          ]),
        );
  final seen = <String>{};
  final genres = <String>[];
  for (final part in parts) {
    final name = part.trim();
    final key = genreKey(name);
    if (key.isNotEmpty && seen.add(key)) genres.add(name);
  }
  return genres;
}

void main() {
  const samples = [
    '',
    ' ',
    'Ann',
    'A;B',
    'A ; B',
    'A feat. B',
    'A Feat B',
    'A FT. B',
    'A ft B',
    'A featuring B',
    'A with B',
    'A (feat. B)',
    'A [ft. B; C]',
    'A (with B) ; C',
    'A/B',
    'A / B',
    'AC/DC',
    'ac/dc',
    'AC / DC',
    'AC/DC feat. Foo',
    'Foo/AC/DC',
    'AC/DC/AC/DC',
    'Shellac/DC Talk',
    'Lefty Feather',
    'Withers',
    'A ; with B',
    'A / feat. B',
    'A with / B',
    'A (feat. ) with B',
    'A with (feat. B)',
    'Beyonce\u0301; Beyoncé',
    'Ban nhạc Hương Mùa Hè;SUNI Hạ Linh',
    'Tyler, The Creator & Co',
    'A\tfeat.\tB',
    'x\u0000y;z',
    'A\u200b;\u200bB',
    'Rock; Pop ;Jazz',
    'rock;ROCK; Rock',
    'Rock/Pop',
    'Rock;\u200b',
    '  ; ',
    'Rock;;',
  ];

  const vocabulary = [
    ';',
    '/',
    '(',
    ')',
    '[',
    ']',
    'feat',
    'feat.',
    'ft',
    'ft.',
    'featuring',
    'with',
    'FEAT',
    'With',
    'AC',
    'DC',
    'ac/dc',
    ',',
    '&',
    'x',
    ' ',
    ' ',
    ' ',
    '\t',
    '\u0000',
    '\u200b',
    'e\u0301',
    'é',
    'Ánh',
  ];

  List<String> generated(int count) {
    final random = Random(20261023);
    return [
      for (var i = 0; i < count; i++)
        [
          for (var n = random.nextInt(9); n >= 0; n--)
            vocabulary[random.nextInt(vocabulary.length)],
        ].join(),
    ];
  }

  test('the old artist rules give what the old splitting gave', () {
    for (final input in [...samples, ...generated(20000)]) {
      expect(
        splitArtists(input, rules: _oldArtistRules),
        oracleSplitArtists(input),
        reason: 'input ${input.codeUnits}',
      );
    }
  });

  test('default genre rules give what the old splitting gave', () {
    for (final input in [...samples, ...generated(20000)]) {
      expect(
        splitGenres(input),
        oracleSplitGenres(input),
        reason: 'input ${input.codeUnits}',
      );
    }
  });

  test('null gives nothing in both', () {
    expect(
      splitArtists(null, rules: _oldArtistRules),
      oracleSplitArtists(null),
    );
    expect(splitGenres(null), oracleSplitGenres(null));
  });
}
