import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/app_directories_provider.dart';
import 'package:kanaru/features/settings/open_external.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

late ProviderContainer container;

/// Pumps the whole app (no forced locale) on the settings page.
Future<void> pumpSettings(
  WidgetTester tester, {
  AppDirectoryPaths paths = const AppDirectoryPaths(
    config: '/cfg/kanaru',
    data: '/data/kanaru',
    cache: '/cache/kanaru',
  ),
  Future<bool> Function(String) open = _alwaysOpens,
  SettingsFile? file,
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      appDirectoryPathsProvider.overrideWithValue(paths),
      openExternalProvider.overrideWithValue(open),
      settingsFileProvider.overrideWithValue(file),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

Future<bool> _alwaysOpens(String _) async => true;

void main() {
  testWidgets('shows the three sections', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('About'), findsWidgets);
    expect(find.text('GPL-3.0-or-later'), findsOneWidget);
  });

  testWidgets('choosing Dark switches the app theme', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).theme, ThemePreference.dark);
    final context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('choosing Tiếng Việt switches the UI language', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếng Việt').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).languageCode, 'vi');
    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
  });

  testWidgets('title bar change asks for a restart until changed back', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.text('Applies after restart'), findsNothing);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(find.text('Applies after restart'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<TitleBarPreference>),
        matching: find.text('Kanaru'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Applies after restart'), findsNothing);
  });

  testWidgets('shows directories and opens one', (tester) async {
    final opened = <String>[];
    await pumpSettings(
      tester,
      open: (target) async {
        opened.add(target);
        return true;
      },
    );
    expect(find.text('/cfg/kanaru'), findsOneWidget);

    // The directory does not exist: use a real temp path for the open.
    final dir = Directory.systemTemp.createTempSync('kanaru_settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(const SizedBox());
    await pumpSettings(
      tester,
      paths: AppDirectoryPaths(config: '${dir.path}/c'),
      open: (target) async {
        opened.add(target);
        return true;
      },
    );
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Open folder'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(opened, ['${dir.path}/c']);
    expect(find.text('Unknown'), findsNWidgets(2));
    expect(find.byTooltip('Open folder'), findsOneWidget);
  });

  testWidgets('a failed open shows an error snackbar', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpSettings(
      tester,
      paths: AppDirectoryPaths(data: '${dir.path}/d'),
      open: (_) async => false,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Open folder'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text("Couldn't open ${dir.path}/d"), findsOneWidget);
  });

  testWidgets('warns when settings are read-only', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/settings.json';
    File(path).writeAsStringSync('{"version": 99}');
    final file = SettingsFile(path)..load();
    await pumpSettings(tester, file: file);

    expect(
      find.text("Settings can't be saved this session ($path)"),
      findsOneWidget,
    );
  });

  testWidgets('reset asks first, then restores defaults', (tester) async {
    await pumpSettings(tester);
    container.read(settingsProvider.notifier).setTheme(ThemePreference.dark);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset all settings'));
    await tester.tap(find.text('Reset all settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).theme, ThemePreference.dark);

    await tester.tap(find.text('Reset all settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider), const AppSettings());
    expect(find.text('Settings were reset'), findsOneWidget);
  });

  testWidgets('source code link opens the repository', (tester) async {
    final opened = <String>[];
    await pumpSettings(
      tester,
      open: (target) async {
        opened.add(target);
        return true;
      },
    );

    await tester.ensureVisible(find.text('Source code'));
    await tester.tap(find.text('Source code'));
    await tester.pump();

    expect(opened, ['https://github.com/kanaru313/kanaru']);
  });

  testWidgets('open source licenses opens the license page', (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.text('Open source licenses'));
    await tester.tap(find.text('Open source licenses'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
