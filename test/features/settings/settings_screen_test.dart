import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/applied_appearance_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/open_external.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'settings_page_opener.dart';

late ProviderContainer container;

/// Pumps the whole app (no forced locale) on the Settings root, or on the
/// page behind the tile titled [page].
Future<void> pumpSettings(
  WidgetTester tester, {
  String? page,
  Future<bool> Function(String) open = _alwaysOpens,
  SettingsFile? file,
}) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
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
  if (page != null) await openSettingsPage(tester, page);
}

Future<bool> _alwaysOpens(String _) async => true;

/// Top edge of the group headed [title] on the page shown.
double _groupTop(WidgetTester tester, String title) => tester
    .getTopLeft(
      find.byWidgetPredicate((w) => w is SettingsSection && w.title == title),
    )
    .dy;

double _rowTop(WidgetTester tester, String title) => tester
    .getTopLeft(
      find.byWidgetPredicate((w) => w is SettingRow && w.title == title),
    )
    .dy;

void _expectAscending(List<double> tops, {String? reason}) {
  expect(tops, orderedEquals([...tops]..sort()), reason: reason);
  expect(tops.toSet(), hasLength(tops.length), reason: reason);
}

void main() {
  testWidgets('the root has no save warning', (tester) async {
    await pumpSettings(tester);

    expect(find.byIcon(AppIcons.warningOutlined), findsNothing);
  });

  testWidgets('each page shows its groups in order, rows with a hint', (
    tester,
  ) async {
    final groups = {
      'Appearance': ['Theme', 'Text', 'Layout'],
      'Playback': ['Playback', 'Lyrics', 'Translation'],
      'Library': ['Folders', 'Scanning', 'Organization'],
      'Data & storage': ['Backup and restore', 'Caches', 'Logs'],
    };
    await pumpSettings(tester);
    for (final MapEntry(key: page, value: titles) in groups.entries) {
      await openSettingsPage(tester, page);
      _expectAscending([
        for (final title in titles) _groupTop(tester, title),
      ], reason: page);
      final rows = find.byType(SettingRow).evaluate();
      for (final row in rows) {
        final widget = row.widget as SettingRow;
        expect(widget.subtitle, isNotNull, reason: '$page: ${widget.title}');
      }
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('rows keep their order inside the Appearance groups', (
    tester,
  ) async {
    await pumpSettings(tester, page: 'Appearance');

    _expectAscending([
      _rowTop(tester, 'Theme'),
      _rowTop(tester, 'Colors from the cover'),
      _rowTop(tester, 'Animations'),
    ]);
    _expectAscending([
      _rowTop(tester, 'Font'),
      _rowTop(tester, 'Text size'),
      _rowTop(tester, 'Language'),
    ]);
    _expectAscending([
      tester.getTopLeft(find.text('Sidebar tabs')).dy,
      _rowTop(tester, 'Track numbers in albums'),
      _rowTop(tester, 'Waveform seek bar'),
      _rowTop(tester, 'Title bar'),
    ]);
    _expectAscending([
      _groupTop(tester, 'Theme'),
      _rowTop(tester, 'Theme'),
      _groupTop(tester, 'Text'),
      _rowTop(tester, 'Font'),
      _groupTop(tester, 'Layout'),
      tester.getTopLeft(find.text('Sidebar tabs')).dy,
    ]);
  });

  testWidgets(
    'Library lists the counts, then Folders, Scanning, Organization',
    (tester) async {
      await pumpSettings(tester, page: 'Library');

      _expectAscending([
        _groupTop(tester, 'Folders'),
        _groupTop(tester, 'Scanning'),
        tester.getTopLeft(find.text('Rescan library')).dy,
        _groupTop(tester, 'Organization'),
        tester.getTopLeft(find.text('Group albums by')).dy,
      ]);
      expect(find.text('Rescan library'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Rescan'))
            .onPressed,
        isNull,
        reason: 'no library database in this test',
      );
    },
  );

  testWidgets('About shows the license', (tester) async {
    await pumpSettings(tester, page: 'About');

    expect(find.text('GPL-3.0-or-later'), findsOneWidget);
  });

  testWidgets('Open-source licenses opens the licenses page', (tester) async {
    await pumpSettings(tester, page: 'About');

    final tile = find.text('Open-source licenses');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('choosing Dark switches the app theme', (tester) async {
    await pumpSettings(tester, page: 'Appearance');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).theme, ThemePreference.dark);
    final context = tester.element(find.text('Theme').first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('choosing Tiếng Việt switches the UI language', (tester) async {
    await pumpSettings(tester, page: 'Appearance');

    // The font dropdown comes before the language dropdown on the page.
    await tester.tap(find.byType(DropdownMenu<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếng Việt').last);
    await tester.pumpAndSettle();
    // The language reaches the app only after the short apply pause.
    await tester.pump(appearanceApplyDelay);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).languageCode, 'vi');
    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
  });

  testWidgets('title bar change asks for a restart until changed back', (
    tester,
  ) async {
    await pumpSettings(tester, page: 'Appearance');
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

  testWidgets('a failed open shows an error snackbar', (tester) async {
    await pumpSettings(tester, page: 'About', open: (_) async => false);

    await tester.ensureVisible(find.text('Source code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source code'));
    await tester.pump();

    expect(
      find.text("Couldn't open https://github.com/kanaru313/kanaru"),
      findsOneWidget,
    );
  });

  testWidgets('warns when settings are read-only, on the root and a page', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/settings.json';
    File(path).writeAsStringSync('{"version": 99}');
    final file = SettingsFile(path)..load();
    await pumpSettings(tester, file: file);

    final warning = find.text("Settings can't be saved this session ($path)");
    expect(warning, findsOneWidget);

    await openSettingsPage(tester, 'Appearance');
    expect(warning, findsOneWidget);
  });

  testWidgets('source code link opens the repository', (tester) async {
    final opened = <String>[];
    await pumpSettings(
      tester,
      page: 'About',
      open: (target) async {
        opened.add(target);
        return true;
      },
    );

    await tester.ensureVisible(find.text('Source code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source code'));
    await tester.pump();

    expect(opened, ['https://github.com/kanaru313/kanaru']);
  });
}
