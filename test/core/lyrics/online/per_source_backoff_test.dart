import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_backoff.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';

import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

LyricsTarget _song(String name) => LyricsTarget.fromFields(
  uri: '/music/${name.hashCode}.flac',
  title: name,
  artist: 'Artist',
  album: 'Alb',
  duration: const Duration(seconds: 200),
);

void main() {
  late FakeLyricsProvider plugin;
  late FakeLyricsProvider lrclib;

  Future<LyricsHarness> harness() {
    plugin = FakeLyricsProvider(id: 'plugin');
    lrclib = FakeLyricsProvider(id: 'lrclib');
    return createHarness([
      LyricsProviderRegistration(plugin),
      LyricsProviderRegistration(lrclib),
    ]);
  }

  test(
    'a failing source pauses itself, the next song still asks the other',
    () async {
      final h = await harness();
      plugin.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      lrclib.lookupResult = null;

      await h.lookups.start(_song('Song One'), auto: true);
      expect((plugin.lookupCalls, lrclib.lookupCalls), (1, 1));
      expect(h.backoff.isPaused('plugin'), isTrue);
      expect(h.backoff.isPaused('lrclib'), isFalse);

      await h.lookups.start(_song('Song Two'), auto: true);
      // The plugin is skipped; LRCLIB runs again.
      expect((plugin.lookupCalls, lrclib.lookupCalls), (1, 2));
    },
  );

  test('a pause ends by itself and the source is asked again', () async {
    final h = await harness();
    plugin.lookupResult = const LyricsFetchException(LyricsFetchKind.network);

    await h.lookups.start(_song('Song One'), auto: true);
    h.now = h.now.add(minBackoff + const Duration(seconds: 1));
    await h.lookups.start(_song('Song Two'), auto: true);

    expect(plugin.lookupCalls, 2);
  });

  test('retry-after pauses only the source that asked for it', () async {
    final h = await harness();
    plugin.lookupResult = const LyricsFetchException(
      LyricsFetchKind.rateLimited,
      retryAfter: Duration(minutes: 5),
    );

    await h.lookups.start(_song('Song One'), auto: true);
    h.now = h.now.add(const Duration(minutes: 4));

    expect(h.backoff.isPaused('plugin'), isTrue);
    expect(h.backoff.isPaused('lrclib'), isFalse);
  });

  test('clear lifts every pause', () async {
    final h = await harness();
    h.backoff.failed('plugin');
    h.backoff.failed('lrclib');
    expect(h.backoff.isBlocked, isTrue);

    h.backoff.clear();

    expect(h.backoff.isBlocked, isFalse);
    expect(h.backoff.isPaused('plugin'), isFalse);
  });

  test('a manual lookup asks a paused source too', () async {
    final h = await harness();
    h.backoff.failed('plugin');

    await h.lookups.start(_song('Song One'), auto: false);

    expect(plugin.lookupCalls, 1);
  });

  test('a source that fails still pauses when a later one finds', () async {
    final h = await harness();
    plugin.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
    lrclib.lookupResult = fakeCandidate(
      providerId: 'lrclib',
      title: 'Song One',
    );

    await h.lookups.start(_song('Song One'), auto: true);

    expect(h.backoff.isPaused('plugin'), isTrue);
    expect(h.backoff.isPaused('lrclib'), isFalse);
    expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
  });

  test('a cache read failure pauses every enabled source', () async {
    final h = await harness();
    await h.db.customStatement('DROP TABLE online_lyrics');

    await h.lookups.start(_song('Song One'), auto: true);

    expect(plugin.lookupCalls + lrclib.lookupCalls, 0);
    expect(h.backoff.isPaused('plugin'), isTrue);
    expect(h.backoff.isPaused('lrclib'), isTrue);
  });

  test('a failure after Clear pauses nothing, even with two sources', () async {
    final h = await harness();
    plugin.gate = Completer();
    plugin.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
    lrclib.lookupResult = const LyricsFetchException(LyricsFetchKind.network);

    final done = h.lookups.start(_song('Song One'), auto: true);
    await Future<void>.delayed(Duration.zero);
    h.lookups.forgetFailures();
    plugin.gate!.complete();
    await done;

    expect(lrclib.lookupCalls, 1);
    expect(h.backoff.isBlocked, isFalse);
    expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
  });

  group('a skipped source', () {
    test('is no failure, no pause and no row; the others still run', () async {
      final h = await harness();
      final target = _song('Song One');
      plugin.lookupResult = const LyricsSourceSkipped();
      lrclib.lookupResult = fakeCandidate(
        providerId: 'lrclib',
        title: 'Song One',
      );

      await h.lookups.start(target, auto: true);

      expect(h.backoff.isBlocked, isFalse);
      expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
      final rows = await h.db.watchOnlineLyrics(target.cacheKey).first;
      expect(rows.map((r) => r.providerId), ['lrclib']);
    });

    test('alone it leaves no state and is asked again next time', () async {
      final h = await harness();
      final target = _song('Song One');
      plugin.lookupResult = const LyricsSourceSkipped();
      lrclib.lookupResult = const LyricsSourceSkipped();

      await h.lookups.start(target, auto: true);
      await h.lookups.start(target, auto: true);

      expect(plugin.lookupCalls, 2);
      expect(h.backoff.isBlocked, isFalse);
      expect(await h.db.watchOnlineLyrics(target.cacheKey).first, isEmpty);
    });

    test('in the extra search keeps the plain exact hit', () async {
      final h = await harness();
      final target = _song('Song One');
      plugin.lookupResult = fakeCandidate(
        providerId: 'plugin',
        title: 'Song One',
        body: const LyricsBody(plain: 'words'),
      );
      plugin.searchResult = const LyricsSourceSkipped();
      lrclib.lookupResult = const LyricsSourceSkipped();

      await h.lookups.start(target, auto: true);

      final rows = await h.db.watchOnlineLyrics(target.cacheKey).first;
      expect(rows.map((r) => (r.providerId, r.status)), [
        ('plugin', OnlineLyricsStatus.found.value),
      ]);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('in the search of a lookup stores no not_found', () async {
      final h = await harness();
      final target = _song('Song One');
      plugin.searchResult = const LyricsSourceSkipped();
      lrclib.lookupResult = const LyricsSourceSkipped();

      await h.lookups.start(target, auto: true);

      expect(await h.db.watchOnlineLyrics(target.cacheKey).first, isEmpty);
    });
  });
}
