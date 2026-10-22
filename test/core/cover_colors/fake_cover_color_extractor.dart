import 'dart:async';

import 'package:kanaru/core/cover_colors/cover_color_extractor.dart';

/// A [CoverColorExtractor] for tests: [colors] gives each key's sample
/// (`null` = fails), every call is recorded, and [gate] (when set) holds the
/// answer until it completes. [error] makes calls throw.
class FakeCoverColorExtractor implements CoverColorExtractor {
  FakeCoverColorExtractor({Map<String, CoverColorSample?>? colors})
    : colors = colors ?? {};

  final Map<String, CoverColorSample?> colors;
  final calls = <(List<String>, bool)>[];
  Completer<void>? gate;
  Object? error;

  @override
  Future<List<CoverColorSample>> extract(
    List<String> keys, {
    required bool background,
  }) async {
    calls.add((List.of(keys), background));
    final waiting = gate;
    if (waiting != null) await waiting.future;
    final failure = error;
    if (failure != null) throw failure;
    return [
      for (final key in keys)
        colors.containsKey(key)
            ? colors[key] ?? CoverColorSample(key: key, ok: false)
            : sampleFor(key),
    ];
  }
}

/// A distinct, valid sample for [key]: the seed and palette depend on the
/// key's hash so different keys get different colors.
CoverColorSample sampleFor(String key, {int? seed}) {
  final shade = key.hashCode & 0xFFFFFF;
  return CoverColorSample(
    key: key,
    ok: true,
    seed: seed ?? (0xFF000000 | shade),
    palette: [0xFF000000 | shade, 0xFF102030],
  );
}

/// A cover key (`<ab>/<hash>.jpg`) made from [n].
String keyFor(int n) {
  final hash = n.toRadixString(16).padLeft(64, '0');
  return '${hash.substring(0, 2)}/$hash.jpg';
}
