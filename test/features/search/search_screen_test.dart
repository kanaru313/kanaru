import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/features/search/search_request_provider.dart';

import '../library/browse_test_data.dart';

import 'package:kanaru/shared/widgets/library_loading.dart';

import '../../core/indexer/scripted_indexer.dart';
import '../library/library_test_harness.dart';
import 'search_test_data.dart';

void main() {
  for (final query in ['', '!!!']) {
    testWidgets('no search words shows the search hint ("$query")', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(tester, h, query);

      expect(find.text('Search your library'), findsOneWidget);
      expect(find.text('No results'), findsNothing);
    });
  }

  testWidgets('without a library database says the library is unavailable', (
    tester,
  ) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/search?q=son');
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open the library"), findsOneWidget);
  });

  testWidgets('without music folders says the library is empty', (
    tester,
  ) async {
    final h = LibraryHarness();
    await h.pump(tester);
    goTo(tester, h, '/search?q=son');
    await tester.pumpAndSettle();

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('shows the updating state until the keys are ready', (
    tester,
  ) async {
    final finish = Completer<void>();
    final h = LibraryHarness(
      overrides: [
        libraryKeysRunnerProvider.overrideWithValue((
          db,
          rules,
          onProgress,
        ) async {
          onProgress(2000, 10000);
          await finish.future;
        }),
      ],
    );
    await insertTracks(tester, h, searchTracks);
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/search?q=son');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Updating library…'), findsOneWidget);
    expect(find.text('Sơn Tùng M-TP'), findsNothing);

    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Updating library…'), findsNothing);
    expect(find.text('Lạc Trôi'), findsOneWidget);
  });

  testWidgets('no match says nothing matches the query', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'zzzz');

    expect(find.text('No results'), findsOneWidget);
    expect(find.textContaining('Nothing matches “zzzz”'), findsOneWidget);
  });

  testWidgets('keeps the previous results while the next query loads', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');
    expect(find.text('Lạc Trôi'), findsOneWidget);

    goTo(tester, h, '/search?q=adele');
    await tester.pump();
    expect(find.text('Lạc Trôi'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Lạc Trôi'), findsNothing);
  });

  testWidgets('a failed query shows the error, not the previous results', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        searchSongsProvider(requestFor('adele'))
            .overrideWith((ref) => Stream.error(StateError('boom'))),
      ],
    );
    await openSearch(tester, h, 'son tung');
    expect(find.text('Lạc Trôi'), findsOneWidget);

    goTo(tester, h, '/search?q=adele');
    await tester.pumpAndSettle();

    expect(find.text('Search failed'), findsOneWidget);
    expect(find.text("Couldn't open the library"), findsNothing);
    expect(find.text('Lạc Trôi'), findsNothing);

    goTo(tester, h, '/search?q=son+tung');
    await tester.pumpAndSettle();
    expect(find.text('Lạc Trôi'), findsOneWidget);
    expect(find.text('Search failed'), findsNothing);
  });

  testWidgets('a failed first query shows the error', (tester) async {
    final h = LibraryHarness(
      overrides: [
        searchSongsProvider(requestFor('son'))
            .overrideWith((ref) => Stream.error(StateError('boom'))),
      ],
    );
    await openSearch(tester, h, 'son');

    expect(find.text('Search failed'), findsOneWidget);
  });

  testWidgets('no results while scanning shows loading, not "No results"', (
    tester,
  ) async {
    final indexer = ScriptedIndexer();
    final h = LibraryHarness(
      overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
    );
    await openSearch(tester, h, 'zzzz');
    expect(find.text('No results'), findsOneWidget);

    indexer.emit(
      const IndexerScanning(phase: ScanPhase.reading, rootPath: '/m'),
    );
    await tester.pump();
    expect(find.text('No results'), findsNothing);
    expect(find.byType(LibraryLoading), findsOneWidget);

    // Results found during a scan show as usual.
    goTo(tester, h, '/search?q=son+tung');
    // A scan without progress shows the top bar's rescan ring spinning,
    // so the frames never settle: pump a bounded time instead.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Lạc Trôi'), findsOneWidget);

    indexer.emit(IndexerFinished(const ScanSummary()));
    goTo(tester, h, '/search?q=zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
  });
}
