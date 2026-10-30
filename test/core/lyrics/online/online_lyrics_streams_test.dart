import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';

import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

OnlineLyricsCompanion _row(
  String provider, {
  String status = 'found',
  String? remoteId = 'r',
  String? synced = '[00:01.00] hello',
  int fetchedAt = 1,
}) => OnlineLyricsCompanion.insert(
  cacheKey: 'key',
  providerId: provider,
  status: status,
  remoteId: Value(remoteId),
  syncedText: Value(synced),
  fetchedAt: fetchedAt,
);

void main() {
  late LyricsHarness h;
  late ProviderContainer container;

  setUp(() async {
    h = await createHarness([
      LyricsProviderRegistration(FakeLyricsProvider(id: 'first')),
      LyricsProviderRegistration(FakeLyricsProvider(id: 'second')),
    ]);
    container = h.container;
  });

  Future<T> settled<T>(StreamProvider<T> provider) async {
    // The listener keeps the autoDispose family alive between reads.
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('cache entries', () {
    test('are in registry order and ignore unregistered providers', () async {
      await h.db.saveOnlineLyrics(_row('unknown'));
      await h.db.saveOnlineLyrics(_row('second', remoteId: 'b'));
      await h.db.saveOnlineLyrics(_row('first', remoteId: 'a'));

      final entries = await settled(onlineLyricsCacheProvider('key'));

      expect(entries.map((e) => e.providerId), ['first', 'second']);
      expect(entries.first.lyrics!.synced, isTrue);
      expect(entries.first.remoteId, 'a');
    });

    test('rows with an unknown status are skipped', () async {
      await h.db.saveOnlineLyrics(_row('first', status: 'future'));
      expect(await settled(onlineLyricsCacheProvider('key')), isEmpty);
    });

    test('an unrelated write keeps the same Lyrics instance', () async {
      await h.db.saveOnlineLyrics(_row('first'));
      final provider = onlineLyricsCacheProvider('key');
      final emissions = <List<OnlineLyricsEntry>>[];
      container.listen(provider, (_, next) {
        if (next.hasValue) emissions.add(next.requireValue);
      }, fireImmediately: true);
      await pump();
      final lyrics = emissions.last.single.lyrics;

      await h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'other',
          providerId: 'first',
          status: 'not_found',
          fetchedAt: 5,
        ),
      );
      await h.db.saveOnlineLyrics(_row('unknown', remoteId: 'z'));
      await pump();

      expect(emissions, hasLength(1));
      expect(
        identical(container.read(provider).requireValue.single.lyrics, lyrics),
        isTrue,
      );
    });

    test('a replaced row parses again', () async {
      await h.db.saveOnlineLyrics(_row('first'));
      final provider = onlineLyricsCacheProvider('key');
      final before = (await settled(provider)).single.lyrics;

      await h.db.saveOnlineLyrics(_row('first', fetchedAt: 2));
      await pump();

      final after = container.read(provider).requireValue.single.lyrics;
      expect(identical(after, before), isFalse);
      expect(after!.lines.single.text, 'hello');
    });

    test('plain text is used when the synced text is blank', () async {
      await h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'key',
          providerId: 'first',
          status: 'found',
          remoteId: const Value('r'),
          syncedText: const Value('  '),
          plainText: const Value('words\nmore'),
          fetchedAt: 1,
        ),
      );
      final lyrics = (await settled(onlineLyricsCacheProvider('key')))
          .single
          .lyrics!;
      expect(lyrics.synced, isFalse);
      expect(lyrics.lines, hasLength(2));
    });

    test('an instrumental and a not_found entry carry no lyrics', () async {
      await h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'key',
          providerId: 'first',
          status: 'found',
          remoteId: const Value('r'),
          instrumental: const Value(true),
          fetchedAt: 1,
        ),
      );
      await h.db.saveOnlineLyrics(
        _row('second', status: 'not_found', remoteId: null, synced: null),
      );
      final entries = await settled(onlineLyricsCacheProvider('key'));
      expect(entries.map((e) => e.lyrics), [null, null]);
      expect(entries.first.instrumental, isTrue);
      expect(entries.last.status, OnlineLyricsStatus.notFound);
    });
  });

  group('pins', () {
    test('no row gives null', () async {
      expect(await settled(lyricsPinProvider('/a.flac')), isNull);
    });

    test('a pick has parsed lyrics, a choice alone has no pick', () async {
      await h.db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: '/a.flac',
          pinnedAt: 1,
          providerId: const Value('first'),
          remoteId: const Value('r'),
          syncedText: const Value('[00:02.00] pinned'),
        ),
      );
      await h.db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: '/b.flac', pinnedAt: 1),
      );

      final pick = (await settled(lyricsPinProvider('/a.flac')))!;
      final bare = (await settled(lyricsPinProvider('/b.flac')))!;

      expect(pick.hasPick, isTrue);
      expect(pick.choice, LyricsChoice.auto);
      expect(pick.lyrics!.lines.single.text, 'pinned');
      expect(bare.hasPick, isFalse);
      expect(bare.lyrics, isNull);
    });

    test('a change of mode alone emits again', () async {
      Future<void> write(String? mode) => h.db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: '/a.flac',
          pinnedAt: 1,
          mode: Value(mode),
          providerId: const Value('first'),
          remoteId: const Value('r'),
          syncedText: const Value('[00:02.00] pinned'),
        ),
      );
      final provider = lyricsPinProvider('/a.flac');
      final seen = <LyricsChoice?>[];
      final sub = container.listen(
        provider,
        (_, next) => seen.add(next.value?.choice),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await write('local');
      await pump();
      await write('online');
      await pump();
      await write('off');
      await pump();

      expect(seen.whereType<LyricsChoice>().toList(), [
        LyricsChoice.local,
        LyricsChoice.online,
        LyricsChoice.off,
      ]);
    });

    test('an unrelated write keeps the same entry', () async {
      await h.db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: '/a.flac',
          pinnedAt: 1,
          remoteId: const Value('r'),
          syncedText: const Value('[00:02.00] pinned'),
        ),
      );
      final provider = lyricsPinProvider('/a.flac');
      final before = (await settled(provider))!.lyrics;

      await h.db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: '/other.flac', pinnedAt: 3),
      );
      await pump();

      expect(
        identical(container.read(provider).requireValue!.lyrics, before),
        isTrue,
      );
    });

    test('removing the pin gives null again', () async {
      await h.db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: '/a.flac', pinnedAt: 1),
      );
      final provider = lyricsPinProvider('/a.flac');
      expect(await settled(provider), isNotNull);

      await h.db.removeLyricsPin('/a.flac');
      await pump();

      expect(container.read(provider).requireValue, isNull);
    });
  });
}
