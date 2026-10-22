import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/album_run_key_cache.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:logging/logging.dart';

import 'audio_sync_test_support.dart';

void main() {
  late List<List<String>> asked;

  Future<Map<String, AlbumRunKey>> lookup(List<String> paths) async {
    asked.add(paths);
    return {for (final p in paths) p: ?albumsByPath[p]};
  }

  setUp(() => asked = []);

  test('a path with no album is cached as such', () async {
    final cache = AlbumRunKeyCache(lookup);
    await cache.ensure(['/m/a1.flac', '/m/s.flac']);
    asked.clear();

    await cache.ensure(['/m/a1.flac', '/m/s.flac']);

    expect(asked, isEmpty);
    expect(cache.has('/m/s.flac'), isTrue);
    expect(cache['/m/s.flac'], isNull);
    expect(cache['/m/a1.flac'], albumOne);
    expect(cache.has('/m/other.flac'), isFalse);
  });

  test('a path being read is waited for, not asked again', () async {
    final gate = Completer<Map<String, AlbumRunKey>>();
    final cache = AlbumRunKeyCache((paths) {
      asked.add(paths);
      return gate.future;
    });

    final first = cache.ensure(['/m/a1.flac']);
    final second = cache.ensure(['/m/a1.flac', '/m/a2.flac']);
    expect(asked, [
      ['/m/a1.flac'],
      ['/m/a2.flac'],
    ]);

    gate.complete({'/m/a1.flac': albumOne, '/m/a2.flac': albumOne});
    await Future.wait([first, second]);
    expect(cache['/m/a2.flac'], albumOne);
  });

  test('keeps at most 256 paths, oldest first', () async {
    final cache = AlbumRunKeyCache(lookup);
    final many = [for (var i = 0; i < 300; i++) '/m/x$i.flac'];
    for (var i = 0; i < 300; i += 50) {
      await cache.ensure(many.sublist(i, i + 50));
    }

    expect(cache.has(many.first), isFalse);
    expect(cache.has(many.last), isTrue);
  });

  test('a failed lookup caches nothing and logs once per message', () async {
    final records = <LogRecord>[];
    final previous = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() {
      subscription.cancel();
      Logger.root.level = previous;
    });
    final cache = AlbumRunKeyCache((_) async => throw StateError('db closed'));

    await cache.ensure(['/m/a1.flac']);
    await cache.ensure(['/m/a1.flac']);

    expect(cache.has('/m/a1.flac'), isFalse);
    expect(records.where((r) => r.level == Level.WARNING), hasLength(1));
  });

  test('a lookup that ends after dispose caches nothing', () async {
    final gate = Completer<Map<String, AlbumRunKey>>();
    final cache = AlbumRunKeyCache((_) => gate.future);

    final pending = cache.ensure(['/m/a1.flac']);
    cache.dispose();
    gate.complete({'/m/a1.flac': albumOne});
    await pending;

    expect(cache.has('/m/a1.flac'), isFalse);
  });
}
