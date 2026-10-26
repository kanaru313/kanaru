import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/waveform/waveform.dart';
import 'package:kanaru/core/waveform/waveform_memory_cache.dart';

Waveform _wave() => Waveform(
  levels: Uint8List.fromList([1]),
  length: const Duration(seconds: 1),
);

void main() {
  test('keeps a miss as an answer apart from an unknown path', () {
    final cache = WaveformMemoryCache()..put('/a', null);
    expect(cache.contains('/a'), isTrue);
    expect(cache.lookup('/a'), isNull);
    expect(cache.contains('/b'), isFalse);
  });

  test('evicts the least recently used entry past its capacity', () {
    final cache = WaveformMemoryCache(capacity: 2)
      ..put('/a', _wave())
      ..put('/b', _wave());
    cache.lookup('/a');
    cache.put('/c', _wave());

    expect(cache.contains('/a'), isTrue);
    expect(cache.contains('/b'), isFalse);
    expect(cache.contains('/c'), isTrue);
  });

  test('putting a path again replaces it and refreshes it', () {
    final first = _wave();
    final second = _wave();
    final cache = WaveformMemoryCache(capacity: 2)
      ..put('/a', first)
      ..put('/b', _wave())
      ..put('/a', second)
      ..put('/c', _wave());

    expect(cache.lookup('/a'), same(second));
    expect(cache.contains('/b'), isFalse);
  });
}
