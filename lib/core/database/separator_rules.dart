/// What separates the names in an artist or genre tag, as data the person can
/// edit: the separators and the names that stay whole. The one matcher behind
/// `splitArtists` and `splitGenres`.
///
/// A separator with a letter or digit in it (`feat.`, `with`) is a word: it
/// splits only with whitespace on each side, in any case, so `Feather` and
/// `Withers` stay whole. A separator without letters (`;`, `/`, `|`) splits
/// wherever it appears. A name to keep whole (`AC/DC`) stays one name when
/// the tag holds it, however the rules would otherwise cut it.
library;

import 'dart:convert';

import '../settings/library_scan_prefs.dart';
import 'text_keys.dart';

/// Separators and keep-whole names, as typed. Equal when their [canonical]
/// forms are, so reordering or re-casing entries changes nothing.
class SplitRules {
  const SplitRules({required this.separators, required this.keepWhole});

  /// What cuts a tag into names.
  final List<String> separators;

  /// Names that hold a separator and are one name. Matched against whole
  /// runs of pieces, ignoring case and whitespace runs.
  final List<String> keepWhole;

  /// The rules in a form that is the same for rules that behave the same:
  /// separators trimmed, lower-cased, whitespace runs collapsed, sorted and
  /// without repeats or empty entries; keep-whole names likewise.
  String get canonical =>
      's:${_normalised(separators).join('\u0001')}\u0002'
      'k:${_normalised(keepWhole).join('\u0001')}';

  /// The compiled matcher, shared by every equal set of rules.
  CompiledSplitter get splitter => _splitterFor(this);

  @override
  bool operator ==(Object other) =>
      other is SplitRules && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() =>
      'SplitRules(separators: $separators, keepWhole: $keepWhole)';
}

/// Artist rules that give the results before the rules could be changed.
const defaultArtistRules = SplitRules(
  separators: defaultArtistSeparators,
  keepWhole: defaultArtistKeepWhole,
);

/// Genre rules that give the results before the rules could be changed.
const defaultGenreRules = SplitRules(
  separators: defaultGenreSeparators,
  keepWhole: [],
);

/// The `keys_version` that rows keyed with [artistRules] carry. The default
/// rules give [textKeysVersion], so a library that never changed them is
/// never touched; any other rules give a version above it that depends on
/// the rules, so changing the rules (or changing back) leaves rows with a
/// different version: stale. Compare versions for inequality, not order.
/// Two different rules share a version with odds of 2^-30; the rows then
/// keep their keys until the next change.
///
/// The album [grouping] is part of the keys too: the default grouping adds
/// nothing, so the result is exactly the one above; any other adds its two
/// switches to the hashed text, so it differs from the defaults and from the
/// other groupings.
int keysVersionFor(
  SplitRules artistRules, [
  AlbumGrouping grouping = const AlbumGrouping(),
]) {
  final canonical = artistRules.canonical;
  final defaultGrouping = grouping == const AlbumGrouping();
  if (canonical == defaultArtistRules.canonical && defaultGrouping) {
    return textKeysVersion;
  }
  final groupingPart = defaultGrouping
      ? ''
      : '\u0003g:${grouping.byAlbumArtist ? 1 : 0},${grouping.byYear ? 1 : 0}';
  final hash = _fnv1a32(
    utf8.encode('$textKeysVersion|$canonical$groupingPart'),
  );
  return textKeysVersion + 1 + (hash & 0x3fffffff);
}

int _fnv1a32(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

final _whitespaceRun = RegExp(r'\s+');

/// [entries] lower-cased, whitespace collapsed (control characters count as
/// whitespace), without empty entries and repeats, sorted.
List<String> _normalised(List<String> entries) => {
  for (final entry in entries)
    if (_collapse(entry) case final text when text.isNotEmpty) text,
}.toList()..sort();

String _collapse(String text) => _collapseRun(withoutControlChars(text));

/// Lower case with whitespace runs collapsed and the ends trimmed. Unlike
/// [_collapse] it keeps control characters: the NUL that stands for a
/// bracket boundary must stop a run from matching.
String _collapseRun(String text) {
  final lower = text.toLowerCase();
  return _hasWhitespaceRun(lower)
      ? lower.replaceAll(_whitespaceRun, ' ').trim()
      : lower.trim();
}

/// Whether [text] has two spaces in a row or whitespace other than a plain
/// space: the only cases where collapsing changes more than the ends. May say
/// yes when it need not (a control character), never no when it must.
bool _hasWhitespaceRun(String text) {
  var previousSpace = false;
  for (final unit in text.codeUnits) {
    if (unit == 0x20) {
      if (previousSpace) return true;
      previousSpace = true;
      continue;
    }
    previousSpace = false;
    final oddSpace =
        unit < 0x20 ||
        unit == 0x7f ||
        unit == 0xa0 ||
        unit == 0x1680 ||
        (unit >= 0x2000 && unit <= 0x200a) ||
        unit == 0x2028 ||
        unit == 0x2029 ||
        unit == 0x202f ||
        unit == 0x205f ||
        unit == 0x3000 ||
        unit == 0xfeff;
    if (oddSpace) return true;
  }
  return false;
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Rules compiled once. Looked up by identity first (a backfill passes the
/// same rules for every row), then by canonical form; few entries are ever
/// live (artist and genre rules, a rules change under way).
final _byIdentity = Expando<CompiledSplitter>('CompiledSplitter');
final _byCanonical = <String, CompiledSplitter>{};
const _maxCompiled = 8;

CompiledSplitter _splitterFor(SplitRules rules) {
  final known = _byIdentity[rules];
  if (known != null) return known;
  final canonical = rules.canonical;
  var splitter = _byCanonical.remove(canonical);
  splitter ??= CompiledSplitter._(
    _normalised(rules.separators),
    _normalised(rules.keepWhole),
  );
  // Re-inserted last: the map keeps the least recently used first.
  _byCanonical[canonical] = splitter;
  if (_byCanonical.length > _maxCompiled) {
    _byCanonical.remove(_byCanonical.keys.first);
  }
  _byIdentity[rules] = splitter;
  return splitter;
}

/// The patterns of one set of [SplitRules].
class CompiledSplitter {
  CompiledSplitter._(List<String> separators, List<String> keepWhole)
    : _keepWhole = keepWhole.toSet() {
    final words = <String>[];
    final symbols = <String>[];
    for (final token in separators) {
      (_wordChar.hasMatch(token) ? words : symbols).add(token);
    }
    // Longest first, so a separator that starts another still wins.
    int byLength(String a, String b) => b.length - a.length;
    words.sort(byLength);
    symbols.sort(byLength);

    // A symbol inside a keep-whole name (the `/` of `AC/DC`) leaves the
    // whitespace around it to its neighbours; the others take it, so
    // `A; with B` keeps `with B` whole while `A / with B` still splits on
    // `with`.
    final inKeepWhole = [
      for (final s in symbols)
        if (keepWhole.any((name) => name.contains(s))) s,
    ];
    final eating = [
      for (final s in symbols)
        if (!inKeepWhole.contains(s)) s,
    ];
    final wordAlternatives = words.map(_wordPattern).join('|');
    final alternatives = [
      if (eating.isNotEmpty)
        '\\s*(?:${eating.map(RegExp.escape).join('|')})\\s*',
      if (words.isNotEmpty) '\\s+(?:$wordAlternatives)\\s+',
      if (inKeepWhole.isNotEmpty)
        '(?:${inKeepWhole.map(RegExp.escape).join('|')})',
    ];
    _symbols = symbols;
    _hasWords = words.isNotEmpty;
    _pattern = alternatives.isEmpty
        ? null
        : RegExp(alternatives.join('|'), caseSensitive: false);
    // Tag text becomes a NUL where a bracketed featuring part was; NUL
    // always separates in artist tags.
    _artistPattern = !_hasWords
        ? _pattern
        : RegExp(
            [...alternatives, '\\s*\\u0000\\s*'].join('|'),
            caseSensitive: false,
          );
    if (words.isNotEmpty) {
      _bracketed = RegExp(
        '\\s*[(\\[]\\s*(?:$wordAlternatives)\\s+([^)\\]]*)[)\\]]',
        caseSensitive: false,
      );
      _wordStart = RegExp(
        '\\s(?:${{for (final w in words) RegExp.escape(String.fromCharCode(w.runes.first))}.join('|')})',
        caseSensitive: false,
      );
    }
    final spans = <int>{
      for (final name in keepWhole)
        if (_pattern case final pattern?) pattern.allMatches(name).length + 1,
    }.where((span) => span >= 2).toList()..sort((a, b) => b - a);
    _spans = spans;
    // The first piece of a run that spells a kept name is the first piece of
    // that name: a cheap test before building the run.
    _firstPieces = {
      for (final name in keepWhole)
        if (_pattern case final pattern?)
          if (pattern.firstMatch(name) case final m?)
            name.substring(0, m.start).trim()
          else
            name,
    };
  }

  final Set<String> _keepWhole;
  late final List<String> _symbols;
  late final bool _hasWords;
  late final RegExp? _pattern;
  late final RegExp? _artistPattern;
  RegExp? _bracketed;
  RegExp? _wordStart;
  late final List<int> _spans;
  late final Set<String> _firstPieces;

  static String _wordPattern(String word) =>
      word.split(' ').map(RegExp.escape).join('\\s+');

  /// Whether [text] may hold more than one name: it has a symbol separator,
  /// a bracket (artists only, when words separate), or whitespace followed
  /// by the first letter of a word separator. A cheap test before the
  /// pattern, which costs far more per tag; a false here means one name.
  bool maySplit(String text, {required bool brackets}) {
    for (final symbol in _symbols) {
      if (text.contains(symbol)) return true;
    }
    if (!_hasWords) return false;
    if (brackets && (text.contains('(') || text.contains('['))) return true;
    return _wordStart!.hasMatch(text);
  }

  /// The pieces of [text], trimmed, not empty, in order, without repeats
  /// removed. With [brackets] (artists), a bracketed featuring part such as
  /// `(feat. B)` gives its names too. Names to keep whole come back whole.
  List<String> split(String text, {required bool brackets}) {
    var source = text;
    if (brackets &&
        _bracketed != null &&
        (source.contains('(') || source.contains('['))) {
      source = source.replaceAllMapped(_bracketed!, (m) => '\u0000${m[1]}');
    }
    final pattern = brackets ? _artistPattern : _pattern;
    if (pattern == null) {
      final name = source.trim();
      return name.isEmpty ? const [] : [name];
    }
    final starts = <int>[];
    final ends = <int>[];
    var from = 0;
    for (final match in pattern.allMatches(source)) {
      starts.add(from);
      ends.add(match.start);
      from = match.end;
    }
    starts.add(from);
    ends.add(source.length);

    final names = <String>[];
    void add(String piece) {
      final name = piece.trim();
      if (name.isNotEmpty) names.add(name);
    }

    final count = starts.length;
    var i = 0;
    next:
    while (i < count) {
      // A run of pieces that spells a name to keep whole stays one name:
      // the longest run first, read from the text so the separators in it
      // count.
      final startsRun =
          _spans.isNotEmpty &&
          _firstPieces.contains(
            _collapseRun(source.substring(starts[i], ends[i])),
          );
      for (final span in startsRun ? _spans : const <int>[]) {
        if (i + span > count) continue;
        final run = source.substring(starts[i], ends[i + span - 1]);
        if (_keepWhole.contains(_collapseRun(run))) {
          add(run);
          i += span;
          continue next;
        }
      }
      add(source.substring(starts[i], ends[i]));
      i++;
    }
    return names;
  }
}
