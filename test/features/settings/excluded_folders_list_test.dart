import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

final _onboarded = [
  initialSettingsProvider.overrideWithValue(
    const AppSettings(libraryOnboarded: true),
  ),
];

void main() {
  Future<LibraryHarness> openSettings(
    WidgetTester tester, {
    required String music,
    List<String> excluded = const [],
    List<String> pick = const [],
    LibraryHarness? harness,
  }) async {
    final h = harness ?? LibraryHarness(overrides: _onboarded);
    await tester.runAsync(() async {
      await h.db.addRoots([music], now: 1);
      for (final path in excluded) {
        await h.db.addExcludedFolder(path, 1);
      }
    });
    h.picks.addAll(pick);
    await h.pump(tester, hasRoots: true);
    tester.view.physicalSize = const Size(1280, 2400);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);
    return h;
  }

  Future<List<String>> stored(WidgetTester tester, LibraryHarness h) async =>
      (await tester.runAsync(h.db.excludedFolderPaths))!;

  testWidgets('adds a picked folder as a new row', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    final music = h.folder('music');
    final live = h.folder('music/live');
    await openSettings(tester, music: music, pick: [live], harness: h);

    await tester.tap(find.text('Exclude folder'));
    await settleIo(tester, h);

    expect(find.text(live), findsOneWidget);
    expect(await stored(tester, h), [live]);
  });

  testWidgets('says why a folder was refused', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    final music = h.folder('music');
    final other = h.folder('other');
    final live = h.folder('music/live');
    await openSettings(
      tester,
      music: music,
      excluded: [live],
      pick: [music, other, live],
      harness: h,
    );

    await tester.tap(find.text('Exclude folder'));
    await settleIo(tester, h);
    expect(find.textContaining('That is a music folder'), findsOneWidget);

    await tester.tap(find.text('Exclude folder'));
    await settleIo(tester, h);
    expect(
      find.text('That folder is not inside a music folder.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Exclude folder'));
    await settleIo(tester, h);
    expect(find.text('That folder is already excluded.'), findsOneWidget);
    expect(await stored(tester, h), [live]);
  });

  testWidgets('stopping an exclusion removes the row without asking', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: _onboarded);
    final music = h.folder('music');
    final live = h.folder('music/live');
    await openSettings(tester, music: music, excluded: [live], harness: h);
    expect(find.text(live), findsOneWidget);

    await tester.tap(find.byTooltip('Stop excluding'));
    await settleIo(tester, h);

    expect(find.text(live), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await stored(tester, h), isEmpty);
  });

  testWidgets('an exclusion that no longer applies says so', (tester) async {
    final h = LibraryHarness(overrides: _onboarded);
    final music = h.folder('music');
    final stray = h.folder('stray');
    final gone = '$music/unplugged';
    await openSettings(
      tester,
      music: music,
      excluded: [stray, gone],
      harness: h,
    );

    expect(
      find.text('Not inside a music folder, so it has no effect'),
      findsOneWidget,
    );
    expect(find.text('Folder not found'), findsOneWidget);
    expect(find.byTooltip('Stop excluding'), findsNWidgets(2));
  });
}
