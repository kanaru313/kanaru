import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/stats/listen_clear_scope.dart';
import 'package:kanaru/features/history/history_delete_undo.dart';
import 'package:kanaru/features/history/history_plays_version.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Undo against clears of the History (the recorder's `cleared` stream),
/// without the History page.
void main() {
  late LibraryDatabase db;
  late ProviderContainer container;
  late HistoryDeleteUndo undo;
  late StreamController<ClearBounds> clears;
  late ScaffoldMessengerState messenger;
  late List<int> ids;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    messenger = ScaffoldMessenger.of(tester.element(find.byType(Scaffold)));
  }

  setUp(() {
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    container.listen(historyPlaysVersionProvider, (_, _) {});
    undo = HistoryDeleteUndo();
    clears = StreamController<ClearBounds>.broadcast();
    undo.watchClears(clears.stream);
  });
  tearDown(() async {
    undo.watchClears(null);
    await clears.close();
    container.dispose();
    await db.close();
  });

  /// Plays at 100, 200 and 300, ids kept in [ids].
  Future<void> seed(WidgetTester tester) async {
    ids = (await tester.runAsync(() async {
      return [
        for (final t in [100, 200, 300])
          await db
              .into(db.plays)
              .insert(
                PlaysCompanion.insert(
                  path: '/m/a.flac',
                  playedAt: t,
                  listenedMs: const Value(60000),
                ),
              ),
      ];
    }))!;
  }

  Future<void> deleteAll(WidgetTester tester, {List<int>? only}) async {
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final version = container.read(historyPlaysVersionProvider.notifier);
    await tester.runAsync(
      () => undo.deleteMany(
        db: db,
        messenger: messenger,
        l10n: l10n,
        version: version,
        playIds: only ?? ids,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> clear(WidgetTester tester, ClearBounds bounds) async {
    clears.add(bounds);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<Set<int>> stored(WidgetTester tester) async => {
    for (final p in (await tester.runAsync(() => db.select(db.plays).get()))!)
      p.id,
  };

  testWidgets('a clear drops the plays in its range from the Undo', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    await deleteAll(tester);
    expect(find.text('Removed 3 listens from history'), findsOneWidget);

    await clear(tester, (from: 150, to: 250));

    expect(find.text('Removed 2 listens from history'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(await stored(tester), {ids[0], ids[2]});
  });

  testWidgets('a clear of everything closes the visible snackbar', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    await deleteAll(tester);

    await clear(tester, (from: null, to: null));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsNothing);
    expect(await stored(tester), isEmpty);
  });

  testWidgets('a clear leaves a snackbar that still waits in the queue', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    messenger.showSnackBar(
      const SnackBar(content: Text('Scan done'), persist: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await deleteAll(tester);
    expect(find.text('Undo'), findsNothing);

    await clear(tester, (from: null, to: null));

    // The message on screen is untouched and nothing threw.
    expect(find.text('Scan done'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // It closes itself when its turn comes: there is nothing to undo.
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a clear that lands during a delete leaves no Undo for it', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final version = container.read(historyPlaysVersionProvider.notifier);

    await tester.runAsync(() async {
      final deleting = undo.deleteMany(
        db: db,
        messenger: messenger,
        l10n: l10n,
        version: version,
        playIds: ids,
      );
      clears.add((from: 150, to: 250));
      await deleting;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Removed 2 listens from history'), findsOneWidget);
  });

  testWidgets('a delete wholly inside a clear that landed shows no Undo', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final version = container.read(historyPlaysVersionProvider.notifier);

    await tester.runAsync(() async {
      final deleting = undo.deleteMany(
        db: db,
        messenger: messenger,
        l10n: l10n,
        version: version,
        playIds: ids,
      );
      clears.add((from: null, to: null));
      await deleting;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a delete that starts after a clear keeps all its plays', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final version = container.read(historyPlaysVersionProvider.notifier);

    await tester.runAsync(() async {
      final first = undo.deleteMany(
        db: db,
        messenger: messenger,
        l10n: l10n,
        version: version,
        playIds: [ids[0]],
      );
      clears.add((from: 0, to: 150));
      await Future<void>.delayed(Duration.zero);
      // Starts after the clear, while the first is still in flight.
      final second = undo.deleteMany(
        db: db,
        messenger: messenger,
        l10n: l10n,
        version: version,
        playIds: [ids[0 + 1], ids[2]],
      );
      await Future.wait([first, second]);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Removed 2 listens from history'), findsOneWidget);
  });

  testWidgets('a clear before a delete started does not touch its Undo', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    clears.add((from: 0, to: 1000));
    await tester.pump();

    await deleteAll(tester, only: [ids[0]]);

    expect(find.text('Removed one listen from history'), findsOneWidget);
  });

  testWidgets('after watchClears(null) a clear changes nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    await seed(tester);
    await deleteAll(tester);
    undo.watchClears(null);

    await clear(tester, (from: null, to: null));

    expect(find.text('Removed 3 listens from history'), findsOneWidget);
  });
}
