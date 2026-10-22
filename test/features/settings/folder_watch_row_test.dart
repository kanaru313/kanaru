import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/folder_watcher_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

/// A watcher that has run out of watches.
class _LimitedWatcher extends FolderWatcherController {
  @override
  WatchStatus build() => WatchStatus.limitReached;
}

Finder get _row => find.ancestor(
  of: find.text('Watch music folders'),
  matching: find.byType(SettingRow),
);

Future<LibraryHarness> _open(
  WidgetTester tester, {
  bool hasDatabase = true,
  bool limited = false,
}) async {
  final h = LibraryHarness(
    hasDatabase: hasDatabase,
    overrides: [
      initialSettingsProvider.overrideWithValue(
        const AppSettings(libraryOnboarded: true),
      ),
      if (limited) folderWatcherProvider.overrideWith(_LimitedWatcher.new),
    ],
  );
  await h.pump(tester);
  tester.view.physicalSize = const Size(1280, 4000);
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('the switch is saved and the row has no badge', (tester) async {
    final h = await _open(tester);
    expect(tester.widget<SettingRow>(_row).comingSoon, isFalse);
    expect(
      h.container.read(settingsProvider).libraryScan.watchFolders,
      isFalse,
    );

    await tester.tap(find.descendant(of: _row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(h.container.read(settingsProvider).libraryScan.watchFolders, isTrue);
    expect(find.textContaining('Pick up added, changed'), findsOneWidget);
  });

  testWidgets('without a library database the switch is disabled', (
    tester,
  ) async {
    await _open(tester, hasDatabase: false);

    final control = tester.widget<Switch>(
      find.descendant(of: _row, matching: find.byType(Switch)),
    );
    expect(control.onChanged, isNull);
  });

  testWidgets('when the watches ran out the subtitle says so, value kept', (
    tester,
  ) async {
    final h = await _open(tester, limited: true);

    expect(find.textContaining('fs.inotify.max_user_watches'), findsOneWidget);
    expect(find.textContaining('Pick up added, changed'), findsNothing);
    expect(
      h.container.read(settingsProvider).libraryScan.watchFolders,
      isFalse,
    );
  });
}
