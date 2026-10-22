import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';

import '../library/library_test_harness.dart';

TracksCompanion _track(int rootId, String name, {String? album}) =>
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/$name.mp3',
      mtimeMs: 1,
      sizeBytes: 1,
      title: name,
      addedAt: 1,
      updatedAt: 1,
      artist: const Value('Ann'),
      album: Value(album),
      genre: const Value('Rock'),
    );

void main() {
  testWidgets('counts the library and follows it as tracks arrive', (
    tester,
  ) async {
    final h = LibraryHarness();
    final ids = await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    await tester.runAsync(
      () => h.db.upsertTracks([
        _track(ids!.single, 'a', album: 'One'),
        _track(ids.single, 'b', album: 'One'),
      ]),
    );
    await h.pump(tester, hasRoots: true);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);

    expect(find.text('In your library'), findsOneWidget);
    expect(
      find.text('2 tracks · 1 album · 1 artist · 1 genre'),
      findsOneWidget,
    );

    await tester.runAsync(
      () => h.db.upsertTracks([_track(ids!.single, 'c', album: 'Two')]),
    );
    await settleIo(tester, h);

    expect(
      find.text('3 tracks · 2 albums · 1 artist · 1 genre'),
      findsOneWidget,
    );
  });

  testWidgets('is hidden without a library database', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('In your library'), findsNothing);
    expect(find.text('Music folders'), findsOneWidget);
  });
}
