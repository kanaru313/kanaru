import 'package:drift/drift.dart' show ApplyInterceptor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/stats/listen_recorder.dart';
import 'package:kanaru/core/stats/listen_recorder_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import '../library/library_test_harness.dart';

/// No first-run picker in front of Settings.
final _onboarded = initialSettingsProvider.overrideWithValue(
  const AppSettings(libraryOnboarded: true),
);

void main() {
  // The failing/held cases run a second in-memory database next to the
  // harness's.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final recordSwitch = find.descendant(
    of: find.ancestor(
      of: find.text('Record listen history'),
      matching: find.byType(SettingRow),
    ),
    matching: find.byType(Switch),
  );
  final clearButton = find.widgetWithText(FilledButton, 'Clear');

  Future<void> openSettings(WidgetTester tester, LibraryHarness h) async {
    await h.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
  }

  /// Two plays in the harness database, as if two listens were recorded.
  Future<void> seedPlays(WidgetTester tester, LibraryHarness h) async {
    final roots = await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    await tester.runAsync(() async {
      for (final name in ['a', 'b']) {
        await h.db
            .into(h.db.tracks)
            .insert(
              TracksCompanion.insert(
                rootId: roots!.single,
                path: '/m/$name.mp3',
                mtimeMs: 1,
                sizeBytes: 1,
                title: name,
                addedAt: 1,
                updatedAt: 1,
              ),
            );
        await h.db.insertLibraryPlay(
          path: '/m/$name.mp3',
          playedAt: 10,
          listenedMs: 100,
        );
      }
    });
  }

  Future<int> count(
    WidgetTester tester,
    LibraryHarness h,
    Future<List<Object?>> Function(LibraryDatabase db) read,
  ) async => (await tester.runAsync(() => read(h.db)))!.length;

  Future<void> confirmClear(WidgetTester tester) async {
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('Clear all listen history?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Clear'),
      ),
    );
    // Lets the dialog finish closing.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the switch shows and changes the setting', (tester) async {
    final h = LibraryHarness(overrides: [_onboarded]);
    await openSettings(tester, h);
    expect(find.text('Listen history'), findsOneWidget);
    expect(h.container.read(settingsProvider).recordListenHistory, isTrue);
    expect(tester.widget<Switch>(recordSwitch).value, isTrue);

    await tester.tap(recordSwitch);
    await tester.pumpAndSettle();

    expect(h.container.read(settingsProvider).recordListenHistory, isFalse);
    expect(tester.widget<Switch>(recordSwitch).value, isFalse);
  });

  testWidgets('without a library only the clear button is off', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    expect(tester.widget<Switch>(recordSwitch).onChanged, isNotNull);
  });

  testWidgets('cancelling keeps the history', (tester) async {
    final h = LibraryHarness(overrides: [_onboarded]);
    await openSettings(tester, h);
    await seedPlays(tester, h);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await count(tester, h, (db) => db.select(db.plays).get()), 2);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('confirming empties both tables and says how many', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [_onboarded]);
    await openSettings(tester, h);
    await seedPlays(tester, h);

    await confirmClear(tester);
    await settleIo(tester, h);

    expect(await count(tester, h, (db) => db.select(db.plays).get()), 0);
    expect(await count(tester, h, (db) => db.select(db.playStats).get()), 0);
    expect(find.text('Listen history cleared (2 listens)'), findsOneWidget);
  });

  group('with a recorder on a held or failing database', () {
    late GatedQueryInterceptor gate;
    late LibraryDatabase other;

    LibraryHarness harness() {
      gate = GatedQueryInterceptor();
      other = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
      final recorder = ListenRecorder(
        other,
        enabled: false,
        clock: (now: DateTime.now, elapsed: () => Duration.zero),
      );
      addTearDown(() async {
        recorder.dispose();
        await other.close();
      });
      return LibraryHarness(
        overrides: [
          _onboarded,
          listenRecorderProvider.overrideWith((ref) => recorder),
        ],
      );
    }

    testWidgets('a failure is announced, not thrown', (tester) async {
      final h = harness();
      await openSettings(tester, h);
      gate.failNext('DELETE FROM');

      await confirmClear(tester);
      await settleIo(tester, h);

      expect(find.text('Could not clear listen history'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
    });

    testWidgets('leaving Settings mid-clear still reports the result', (
      tester,
    ) async {
      final h = harness();
      await openSettings(tester, h);
      final release = gate.holdNext('DELETE FROM');

      await confirmClear(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

      h.container.read(routerProvider).go(AppDestination.albums.path);
      await tester.pumpAndSettle();
      expect(clearButton, findsNothing);
      release();
      await settleIo(tester, h);

      expect(tester.takeException(), isNull);
      expect(find.text('Listen history cleared'), findsOneWidget);
    });
  });
}
