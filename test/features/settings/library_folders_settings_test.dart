import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

TracksCompanion _track(int rootId, String path) => TracksCompanion.insert(
  rootId: rootId,
  path: path,
  mtimeMs: 1,
  sizeBytes: 1,
  title: path.split('/').last,
  addedAt: 1,
  updatedAt: 1,
  artist: const Value('Ann'),
);

/// No first-run picker in front of Settings.
final _onboarded = [
  initialSettingsProvider.overrideWithValue(
    const AppSettings(libraryOnboarded: true),
  ),
];

void main() {
  /// Pumps the app with [roots] stored (and `seed` run on the database), then
  /// opens Settings.
  Future<void> openSettings(
    WidgetTester tester,
    LibraryHarness h, {
    List<String> roots = const [],
    Future<void> Function(List<int> ids)? seed,
  }) async {
    final ids = await tester.runAsync(() => h.db.addRoots(roots, now: 1));
    if (seed != null) await tester.runAsync(() => seed(ids!));
    await h.pump(tester, hasRoots: roots.isNotEmpty);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);
  }

  Future<List<String>> storedRoots(
    WidgetTester tester,
    LibraryHarness h,
  ) async => [for (final r in (await tester.runAsync(h.db.roots))!) r.path];

  Future<List<String>> storedTracks(
    WidgetTester tester,
    LibraryHarness h,
  ) async => [
    for (final t in (await tester.runAsync(h.db.select(h.db.tracks).get))!)
      t.path,
  ];

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  Future<void> chooseRowAction(
    WidgetTester tester,
    LibraryHarness h,
    String action,
  ) async {
    await tester.tap(find.byTooltip('Folder actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('lists the folders, a missing one struck through', (
    tester,
  ) async {
    final h = LibraryHarness();
    final present = h.folder('music');
    final gone = '${h.tmp.resolveSymbolicLinksSync()}/unplugged';
    await openSettings(tester, h, roots: [present, gone]);

    expect(find.text(present), findsOneWidget);
    expect(find.text(gone), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(gone)).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      tester.widget<Text>(find.text(present)).style?.decoration,
      isNot(TextDecoration.lineThrough),
    );
    expect(find.text('This folder no longer exists'), findsOneWidget);
    expect(find.byTooltip('Remove from library'), findsOneWidget);
    expect(find.byTooltip('Folder actions'), findsOneWidget);
  });

  testWidgets('the trash button of a missing folder removes it and its songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    final gone = '${h.tmp.resolveSymbolicLinksSync()}/unplugged';
    await openSettings(
      tester,
      h,
      roots: [gone],
      seed: (ids) => h.db.upsertTracks([_track(ids.single, '$gone/a.mp3')]),
    );

    await tester.tap(find.byTooltip('Remove from library'));
    await tester.pumpAndSettle();
    expect(find.text('Remove folder from library?'), findsOneWidget);
    await tester.tap(dialogButton('Remove'));
    await settleIo(tester, h);

    expect(find.text(gone), findsNothing);
    expect(await storedRoots(tester, h), isEmpty);
    expect(await storedTracks(tester, h), isEmpty);
  });

  testWidgets('removing a folder says how many songs go; Cancel keeps it', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    await openSettings(
      tester,
      h,
      roots: [music],
      seed: (ids) => h.db.upsertTracks([
        _track(ids.single, '$music/a.mp3'),
        _track(ids.single, '$music/b.mp3'),
      ]),
    );

    await chooseRowAction(tester, h, 'Remove from library');
    expect(
      find.textContaining('2 songs will leave the library'),
      findsOneWidget,
    );
    await tester.tap(dialogButton('Cancel'));
    await settleIo(tester, h);
    expect(find.text(music), findsOneWidget);
    expect(await storedRoots(tester, h), [music]);

    await chooseRowAction(tester, h, 'Remove from library');
    await tester.tap(dialogButton('Remove'));
    await settleIo(tester, h);
    expect(find.text(music), findsNothing);
    expect(await storedTracks(tester, h), isEmpty);
  });

  testWidgets('adds a folder and scans it', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    final music = h.folder('music');
    h.touch(music, 'one.mp3');
    await openSettings(tester, h);
    h.picks.add(music);

    await tester.tap(find.text('Add folder'));
    await settleIo(tester, h);

    expect(find.text(music), findsOneWidget);
    expect(await storedTracks(tester, h), hasLength(1));
    expect(h.container.read(settingsProvider).libraryOnboarded, isTrue);
  });

  testWidgets('a folder inside an existing one is refused with a message', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    final inner = h.folder('music/rock');
    await openSettings(tester, h, roots: [music]);
    h.picks.add(inner);

    await tester.tap(find.text('Add folder'));
    await settleIo(tester, h);

    expect(find.textContaining('overlaps a folder'), findsOneWidget);
    expect(await storedRoots(tester, h), [music]);
  });

  testWidgets('changing to the same folder asks nothing and writes nothing', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    await openSettings(tester, h, roots: [music]);
    h.picks.add(music);

    await chooseRowAction(tester, h, 'Change folder…');
    await settleIo(tester, h);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await storedRoots(tester, h), [music]);
  });

  testWidgets('changing to another folder replaces it after confirming', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    final other = h.folder('other');
    h.touch(other, 'new.mp3');
    await openSettings(
      tester,
      h,
      roots: [music],
      seed: (ids) => h.db.upsertTracks([_track(ids.single, '$music/old.mp3')]),
    );
    h.picks.add(other);

    await chooseRowAction(tester, h, 'Change folder…');
    await settleIo(tester, h);
    expect(find.textContaining('Replace $music with $other?'), findsOneWidget);
    await tester.tap(dialogButton('Change'));
    await settleIo(tester, h);

    expect(find.text(music), findsNothing);
    expect(find.text(other), findsOneWidget);
    expect(await storedRoots(tester, h), [other]);
    // The scan starts a moment after the write.
    for (var i = 0; i < 50; i++) {
      if ((await storedTracks(tester, h)).isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(await storedTracks(tester, h), ['$other/new.mp3']);
  });

  testWidgets('the startup rescan switch is saved', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    await openSettings(tester, h);
    expect(find.text('Rescan when Kanaru opens'), findsOneWidget);
    expect(h.container.read(settingsProvider).rescanOnStartup, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(h.container.read(settingsProvider).rescanOnStartup, isFalse);
  });

  testWidgets('without a library database the controls are disabled', (
    tester,
  ) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Add folder'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  for (final width in [480.0, 900.0]) {
    testWidgets('long paths and large text fit a ${width.toInt()} px window', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = LibraryHarness();
      final base = h.tmp.resolveSymbolicLinksSync();
      final long = h.folder('a_very_long_folder_name/' * 6);
      final gone = '$base/${'unplugged_drive_' * 8}';
      await openSettings(tester, h, roots: [long, gone]);
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
