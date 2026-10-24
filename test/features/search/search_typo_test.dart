import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show TrackListItem;
import 'package:kanaru/core/database/library_search_queries.dart';
import 'package:kanaru/core/database/search_file_text_index.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/typo_correction.dart';
import 'package:kanaru/features/search/search_request_provider.dart';
import 'package:kanaru/features/search/search_corrected_banner.dart';
import 'package:kanaru/features/search/search_typo_providers.dart';
import 'package:logging/logging.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'search_test_data.dart';

TrackListItem _song(int id) =>
    TrackListItem(id: id, path: '/m/$id.flac', title: 'Song $id');

void main() {
  group('mergeCorrectedSongs', () {
    test('lists real songs first and skips repeats', () {
      final merged = mergeCorrectedSongs(
        SongSearchResult(songs: [_song(1), _song(2)], total: 2),
        SongSearchResult(songs: [_song(3), _song(2), _song(4)], total: 3),
      );

      expect([for (final s in merged.songs) s.id], [1, 2, 3, 4]);
      expect(merged.total, 4);
    });

    test('keeps the real result when the corrected one adds nothing', () {
      final real = SongSearchResult(songs: [_song(1)], total: 1);
      final merged = mergeCorrectedSongs(
        real,
        SongSearchResult(songs: [_song(1)], total: 1),
      );

      expect(merged, same(real));
    });
  });

  testWidgets('a typo finds the song and says what was searched', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'sonn tung');

    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Lạc Trôi'), findsOneWidget);
    expect(find.byType(SearchCorrectedBanner), findsOneWidget);
    expect(find.text('Results for'), findsOneWidget);
    expect(find.text('“son tung”'), findsOneWidget);
    expect(find.text('No results'), findsNothing);
    // The corrected words also find the album and artist.
    expect(find.byType(AlbumListTile), findsOneWidget);
  });

  testWidgets('a correct query has no banner', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.byType(SearchCorrectedBanner), findsNothing);
  });

  testWidgets('a field word is corrected and syntax kept', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'artist:adle');

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Results for'), findsOneWidget);
    expect(find.text('Artist: adele'), findsOneWidget);
  });

  testWidgets('a word that starts a known word is left alone', (tester) async {
    final h = LibraryHarness();
    // "hello" matches one song for real; "helo" is not a prefix of a word.
    await openSearch(
      tester,
      h,
      'hello',
      tracks: const [
        TestTrack('Hello', artist: 'Adele'),
        TestTrack('Hallo Welt', artist: 'Nena'),
      ],
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(SearchCorrectedBanner), findsNothing);
  });

  testWidgets('five real matches are not corrected', (tester) async {
    final h = LibraryHarness();
    await openSearch(
      tester,
      h,
      'tuning',
      tracks: [
        for (var i = 0; i < 5; i++) TestTrack('Tuning $i', artist: 'Band'),
        const TestTrack('Turning', artist: 'Band'),
      ],
    );

    expect(find.byType(SongTile), findsNWidgets(5));
    expect(find.text('Turning'), findsNothing);
    expect(find.byType(SearchCorrectedBanner), findsNothing);
  });

  testWidgets('every typo of a query is fixed together', (tester) async {
    final h = LibraryHarness();
    // Two songs for "beatle", and "beatls" would also fix to "beatles".
    await openSearch(
      tester,
      h,
      'beatles beatls',
      tracks: const [
        TestTrack('Help', artist: 'Beatles'),
        TestTrack('Yesterday', artist: 'Beatles'),
      ],
    );

    // Both words need to match one song; the corrected query has the same
    // word twice and finds both songs.
    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Results for'), findsOneWidget);
    expect(find.text('“beatles beatles”'), findsOneWidget);
  });

  testWidgets('a word far from every known word shows no results', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'zzzzzzzz');

    expect(find.text('No results'), findsOneWidget);
    expect(find.byType(SearchCorrectedBanner), findsNothing);
  });

  group('needsVocabulary', () {
    Future<bool?> flag(WidgetTester tester, LibraryHarness h, String q) async {
      final request = requestFor(q);
      final sub = h.container.listen(searchResultsProvider(request), (_, _) {});
      addTearDown(sub.close);
      await tester.pumpAndSettle();
      return sub.read().value?.needsVocabulary;
    }

    testWidgets('is set when few songs match and a word can be fixed', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'son tung');

      expect(await flag(tester, h, 'son tung'), isTrue);
      expect(await flag(tester, h, 'sonn tung'), isTrue);
    });

    testWidgets('is not set when nothing can be corrected', (tester) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'zz');

      expect(await flag(tester, h, 'zz'), isFalse);
      expect(await flag(tester, h, 'year:2020'), isFalse);
      expect(await flag(tester, h, 'format:flac'), isFalse);
    });

    testWidgets('looks at the real songs, not the merged total', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(
        tester,
        h,
        'tuning',
        tracks: [
          for (var i = 0; i < 5; i++) TestTrack('Tuning $i', artist: 'Band'),
        ],
      );

      expect(await flag(tester, h, 'tuning'), isFalse);
    });

    testWidgets('a typo that finds songs still needs the dictionary', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'sonn tung');

      // The merged result has songs, yet the real search had none.
      final r = h.container
          .read(searchResultsProvider(requestFor('sonn tung')))
          .requireValue;
      expect(r.songTotal, 2);
      expect(r.needsVocabulary, isTrue);
    });
  });

  testWidgets('a word the file name index matches is not corrected', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        searchFileTextIndexProvider.overrideWith(
          (ref) => Stream.value(
            SearchFileTextIndex.buildNow([
              (id: 1, path: '/m/hello.flac', comment: null),
              (id: 2, path: '/m/helo-live.flac', comment: null),
            ]),
          ),
        ),
      ],
    );
    final fields = {...defaultSearchFields, SearchField.fileName};
    await openSearch(
      tester,
      h,
      'helo',
      tracks: const [
        TestTrack('Hello', artist: 'Adele', path: '/m/hello.flac'),
        TestTrack('Other', artist: 'Band', path: '/m/helo-live.flac'),
      ],
    );
    final request = requestFor('helo', fields: fields);
    final sub = h.container.listen(searchResultsProvider(request), (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();

    final r = sub.read().requireValue;
    expect([for (final s in r.songs) s.title], ['Other']);
    expect(r.corrections, isEmpty);
  });

  test('the correction is computed once per request and dictionary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final request = requestFor('beatls');
    final dict = TypoDictionary([(term: 'beatles', doc: 3)]);
    final files = SearchFileTextIndex.buildNow(const []);
    final a = container.read(
      searchTypoCorrectionProvider((request, dict, null)),
    );
    // An equal request object and the same dictionary: the same result.
    final b = container.read(
      searchTypoCorrectionProvider((requestFor('beatls'), dict, null)),
    );

    expect(a, isNotNull);
    expect(b, same(a));
    final other = TypoDictionary([(term: 'beatles', doc: 3)]);
    expect(
      container.read(searchTypoCorrectionProvider((request, other, null))),
      isNot(same(a)),
    );
    expect(
      container.read(searchTypoCorrectionProvider((request, dict, files))),
      isNotNull,
    );
  });

  testWidgets('a failed reload keeps correcting with the last dictionary', (
    tester,
  ) async {
    final warnings = <LogRecord>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level == Level.WARNING)
        .listen(warnings.add);
    addTearDown(sub.cancel);
    final h = LibraryHarness(
      overrides: [
        searchVocabularyProvider.overrideWith((ref) async* {
          yield TypoDictionary([(term: 'son', doc: 2), (term: 'tung', doc: 2)]);
          throw StateError('reload failed');
        }),
      ],
    );
    await openSearch(tester, h, 'sonn tung');

    expect(find.byType(SearchCorrectedBanner), findsOneWidget);
    expect(find.text('Lạc Trôi'), findsOneWidget);
    expect(
      warnings.where((r) => r.message.contains('vocabulary')),
      hasLength(1),
    );
  });
}
