import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';

import '../library/browse_test_data.dart';
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
        libraryKeysRunnerProvider.overrideWithValue((db, onProgress) async {
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
}
