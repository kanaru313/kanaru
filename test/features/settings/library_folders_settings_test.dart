import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
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

/// The switch of the startup rescan row; the listen history row has one too.
final _rescanSwitch = find.descendant(
  of: find.ancestor(
    of: find.text('Rescan when Kanaru opens'),
    matching: find.byType(SettingRow),
  ),
  matching: find.byType(Switch),
);

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
    // Tall, so the folders are on screen below the appearance rows.
    tester.view.physicalSize = const Size(1280, 2400);
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

  TestGesture? mouse;
  setUp(() => mouse = null);

  /// Moves the test's mouse pointer over [target], adding it on first use.
  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    var gesture = mouse;
    if (gesture == null) {
      gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      mouse = gesture;
    }
    await gesture.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    return gesture;
  }

  /// Hovers the folder row of [path] and taps its remove button.
  Future<void> removeRow(WidgetTester tester, String path) async {
    await hover(tester, find.text(path).first);
    await tester.tap(find.byTooltip('Remove from library'));
    await tester.pumpAndSettle();
  }

  /// How opaque the remove button of the (only) folder row is.
  double removeOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byTooltip('Remove from library'),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

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
    // The present folder's button is there too, only invisible.
    expect(find.byTooltip('Remove from library'), findsNWidgets(2));
    expect(find.byTooltip('Folder actions'), findsNothing);
    expect(find.text('Change folder…'), findsNothing);
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

    await removeRow(tester, music);
    expect(
      find.textContaining('2 songs will leave the library'),
      findsOneWidget,
    );
    await tester.tap(dialogButton('Cancel'));
    await settleIo(tester, h);
    // The pointer still rests on the row, so its tooltip shows the path too.
    expect(find.text(music), findsWidgets);
    expect(await storedRoots(tester, h), [music]);

    await removeRow(tester, music);
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

  testWidgets('the remove button shows on hover and hides again', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    await openSettings(tester, h, roots: [music]);
    expect(removeOpacity(tester), 0);

    final pointer = await hover(tester, find.text(music));
    expect(removeOpacity(tester), 1);

    await pointer.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(removeOpacity(tester), 0);
  });

  testWidgets('keyboard focus shows the remove button and Enter asks', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    await openSettings(tester, h, roots: [music]);
    expect(removeOpacity(tester), 0);

    // Tab until focus reaches the hidden button.
    for (var i = 0; i < 40 && removeOpacity(tester) == 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(removeOpacity(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleIo(tester, h);
    expect(find.text('Remove folder from library?'), findsOneWidget);
  });

  testWidgets('a missing folder keeps a red button; a present one does not', (
    tester,
  ) async {
    final h = LibraryHarness();
    final present = h.folder('music');
    final gone = '${h.tmp.resolveSymbolicLinksSync()}/unplugged';
    await openSettings(tester, h, roots: [present, gone]);

    final scheme = Theme.of(tester.element(find.text(present))).colorScheme;
    Color? colorOf(String path) => tester
        .widget<IconButton>(
          find.descendant(
            of: find.ancestor(
              of: find.text(path),
              matching: find.byType(ListTile),
            ),
            matching: find.byType(IconButton),
          ),
        )
        .color;
    double opacityOf(String path) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.ancestor(
              of: find.text(path),
              matching: find.byType(ListTile),
            ),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(opacityOf(gone), 1);
    expect(colorOf(gone), scheme.error);
    expect(opacityOf(present), 0);
    expect(colorOf(present), scheme.onSurface);
  });

  testWidgets('the startup rescan switch is saved', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    await openSettings(tester, h);
    expect(find.text('Rescan when Kanaru opens'), findsOneWidget);
    expect(h.container.read(settingsProvider).rescanOnStartup, isTrue);

    await tester.tap(_rescanSwitch);
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
    expect(tester.widget<Switch>(_rescanSwitch).onChanged, isNull);
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
