import 'dart:isolate';

import '../core/database/text_keys.dart';
import 'sort_compare.dart';

/// Lists longer than this are sorted by [sortByNaturalPath] on another isolate.
const naturalSortIsolateThreshold = 5000;

/// A name cut into runs of ASCII digits and runs of other characters, made
/// once so that sorting many names does not fold the same text again for
/// every comparison. Compare two with [compareNaturalKeys].
class NaturalKey {
  NaturalKey._(this._raw, this._texts, this._numbers, this._zeros);

  final String _raw;

  /// Per chunk: the folded text of a text chunk, or the digits of a number
  /// chunk without leading zeros.
  final List<String> _texts;

  /// Per chunk: whether it is a run of digits.
  final List<bool> _numbers;

  /// Per number chunk, in order: how many leading zeros it had.
  final List<int> _zeros;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// Cuts [name] into a [NaturalKey]. Only ASCII digits count as digits (other
/// digit classes sort as text); text is folded like [sortKey], so "Ánh 2"
/// sits next to "anh 10".
NaturalKey naturalKey(String name) {
  final texts = <String>[];
  final numbers = <bool>[];
  final zeros = <int>[];
  var i = 0;
  while (i < name.length) {
    final digits = _isDigit(name.codeUnitAt(i));
    var end = i + 1;
    while (end < name.length && _isDigit(name.codeUnitAt(end)) == digits) {
      end++;
    }
    final chunk = name.substring(i, end);
    if (digits) {
      var lead = 0;
      while (lead < chunk.length - 1 && chunk.codeUnitAt(lead) == 0x30) {
        lead++;
      }
      // An all-zero run keeps one digit: it is the number 0.
      texts.add(chunk.substring(lead));
      zeros.add(lead);
    } else {
      texts.add(sortKey(chunk));
    }
    numbers.add(digits);
    i = end;
  }
  return NaturalKey._(name, texts, numbers, zeros);
}

/// Orders names the way a file manager does: "Disc 2" before "Disc 10",
/// case and accents ignored. Digit runs compare by value of any length (no
/// overflow); a number sorts before text at the same place. Names equal under
/// that order less zeros first ("2" before "02"), then by code point, so the
/// order is total.
int compareNaturalKeys(NaturalKey a, NaturalKey b) {
  final shared = a._texts.length < b._texts.length
      ? a._texts.length
      : b._texts.length;
  for (var i = 0; i < shared; i++) {
    final aNumber = a._numbers[i], bNumber = b._numbers[i];
    if (aNumber != bNumber) return aNumber ? -1 : 1;
    final x = a._texts[i], y = b._texts[i];
    final order = aNumber
        ? (x.length != y.length ? x.length - y.length : compareCodePoints(x, y))
        : compareCodePoints(x, y);
    if (order != 0) return order;
  }
  if (a._texts.length != b._texts.length) {
    return a._texts.length - b._texts.length;
  }
  for (var i = 0; i < a._zeros.length; i++) {
    if (a._zeros[i] != b._zeros[i]) return a._zeros[i] - b._zeros[i];
  }
  return compareCodePoints(a._raw, b._raw);
}

/// [compareNaturalKeys] for two names, for short lists (folder children);
/// long lists should make the keys once, see [sortByNaturalPath].
int compareNatural(String a, String b) =>
    compareNaturalKeys(naturalKey(a), naturalKey(b));

/// A relative path cut at `/`, each part a [NaturalKey]. Compared part by
/// part, so a folder's files stay together and `Album/x` sorts before
/// `Album (Deluxe)/y`, the way a file manager lists the tree.
class NaturalPathKey {
  NaturalPathKey._(this._parts);

  final List<NaturalKey> _parts;
}

NaturalPathKey naturalPathKey(String path) =>
    NaturalPathKey._([for (final part in path.split('/')) naturalKey(part)]);

/// Parts compare by [compareNaturalKeys]; a path that ends first sorts first.
int compareNaturalPathKeys(NaturalPathKey a, NaturalPathKey b) {
  final shared = a._parts.length < b._parts.length
      ? a._parts.length
      : b._parts.length;
  for (var i = 0; i < shared; i++) {
    final order = compareNaturalKeys(a._parts[i], b._parts[i]);
    if (order != 0) return order;
  }
  return a._parts.length - b._parts.length;
}

/// [compareNaturalPathKeys] for two paths, for tests and short lists.
int compareNaturalPaths(String a, String b) =>
    compareNaturalPathKeys(naturalPathKey(a), naturalPathKey(b));

/// [items] in natural path order of the relative path [path] gives each. The
/// keys are made once; above [naturalSortIsolateThreshold] items the sorting
/// runs on another isolate, so a very large folder does not freeze the UI.
Future<List<T>> sortByNaturalPath<T>(
  List<T> items,
  String Function(T item) path,
) async {
  final paths = [for (final item in items) path(item)];
  final order = paths.length > naturalSortIsolateThreshold
      ? await _naturalOrderInIsolate(paths)
      : _naturalOrder(paths);
  return [for (final i in order) items[i]];
}

/// Indexes of [paths] in natural path order.
List<int> _naturalOrder(List<String> paths) {
  final keys = [for (final path in paths) naturalPathKey(path)];
  return List<int>.generate(paths.length, (i) => i)
    ..sort((a, b) => compareNaturalPathKeys(keys[a], keys[b]));
}

/// [_naturalOrder] on another isolate; top level so that the closure sent
/// over carries nothing but [paths].
Future<List<int>> _naturalOrderInIsolate(List<String> paths) =>
    Isolate.run(() => _naturalOrder(paths));
