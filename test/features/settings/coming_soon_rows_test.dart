import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/features/settings/settings_chips_row.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

/// Values that differ from every default, so a control that shows the
/// default instead of the stored value is caught.
const _stored = AppSettings(
  animations: false,
  libraryScan: LibraryScanPrefs(
    respectNomedia: true,
    minFileSizeKb: 1024,
    minDurationSeconds: 30,
    albumGrouping: AlbumGrouping(byAlbumArtist: false, byYear: true),
  ),
  playback: PlaybackPrefs(
    gapless: false,
    crossfadeSeconds: 6,
    listenThresholdMinutes: 3,
    listenThresholdPercent: 75,
  ),
  display: DisplayPrefs(
    fontScale: 1.25,
    sidebarTabs: {SidebarTab.songs},
    trackNumbersInAlbum: false,
    colorFromCover: false,
  ),
);

late ProviderContainer container;

Future<void> _openApp(WidgetTester tester, AppSettings settings) async {
  tester.view.physicalSize = const Size(1280, 4000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      initialSettingsProvider.overrideWithValue(settings),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
}

/// Shows one settings page; each holds only its own rows.
Future<void> _visit(WidgetTester tester, String route) async {
  container.read(routerProvider).go(route);
  await tester.pumpAndSettle();
}

const _pages = [
  settingsAppearanceRoute,
  settingsPlaybackRoute,
  settingsLibraryRoute,
  settingsDataRoute,
  settingsAdvancedRoute,
];

/// The coming soon rows: every row and chips row marked so.
Iterable<Element> _comingSoonRows() => [
  ...find
      .byType(SettingRow)
      .evaluate()
      .where((e) => (e.widget as SettingRow).comingSoon),
  ...find
      .byType(SettingsChipsRow)
      .evaluate()
      .where((e) => (e.widget as SettingsChipsRow).comingSoon),
];

Finder _inRow(String title, Finder control) => find.descendant(
  of: find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate(
      (w) => w is SettingRow || w is SettingsChipsRow,
    ),
  ),
  matching: control,
);

void main() {
  testWidgets('every row of an option not wired yet has the badge', (
    tester,
  ) async {
    await _openApp(tester, const AppSettings());

    var total = 0;
    for (final page in _pages) {
      await _visit(tester, page);
      final rows = _comingSoonRows().toList();
      expect(find.text('Coming soon'), findsNWidgets(rows.length));
      for (final row in rows) {
        final title = row.widget is SettingRow
            ? (row.widget as SettingRow).title
            : (row.widget as SettingsChipsRow).title;
        final subtitle = row.widget is SettingRow
            ? (row.widget as SettingRow).subtitle
            : (row.widget as SettingsChipsRow).subtitle;
        expect(subtitle, isNotNull, reason: title);
      }
      expect(
        rows.length,
        {
          settingsAppearanceRoute: 0,
          settingsPlaybackRoute: 0,
          settingsLibraryRoute: 2,
          settingsDataRoute: 1,
          settingsAdvancedRoute: 2,
        }[page],
        reason: page,
      );
      total += rows.length;
    }
    expect(total, 5);
  });

  testWidgets('the controls show the stored values', (tester) async {
    await _openApp(tester, _stored);

    bool switchOf(String title) =>
        tester.widget<Switch>(_inRow(title, find.byType(Switch))).value;
    String dropdownText(String title) => tester
        .widget<TextField>(_inRow(title, find.byType(TextField)))
        .controller!
        .text;
    String dropdownTextAt(String title, int index) => tester
        .widget<TextField>(_inRow(title, find.byType(TextField)).at(index))
        .controller!
        .text;
    bool chip(String label) => tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, label))
        .selected;

    await _visit(tester, settingsAppearanceRoute);
    expect(switchOf('Animations'), isFalse);
    expect(switchOf('Colors from the cover'), isFalse);
    expect(switchOf('Track numbers in albums'), isFalse);
    expect(dropdownText('Text size'), '125%');
    expect(chip('Songs'), isTrue);
    expect(chip('Albums'), isFalse);

    await _visit(tester, settingsLibraryRoute);
    expect(switchOf('Skip folders with .nomedia'), isTrue);
    expect(dropdownText('Minimum file size'), '1 MB');
    expect(dropdownText('Minimum length'), '30 s');
    expect(chip('Album title'), isTrue);
    expect(chip('Album artist'), isFalse);
    expect(chip('Year'), isTrue);

    await _visit(tester, settingsAdvancedRoute);
    expect(switchOf('Gapless playback'), isFalse);
    expect(dropdownText('Crossfade'), '6 s');

    await _visit(tester, settingsPlaybackRoute);
    expect(dropdownTextAt('A listen counts after', 0), '3 min');
    expect(dropdownTextAt('A listen counts after', 1), '75%');
  });

  testWidgets('coming soon dropdowns are disabled and open no menu', (
    tester,
  ) async {
    await _openApp(tester, const AppSettings());
    await _visit(tester, settingsAdvancedRoute);

    final menus = [
      for (final row in _comingSoonRows())
        ...find
            .descendant(
              of: find.byElementPredicate((e) => e == row),
              matching: find.byType(DropdownMenu<int>),
            )
            .evaluate(),
    ];
    expect(menus, isNotEmpty);
    for (final menu in menus) {
      expect((menu.widget as DropdownMenu<int>).enabled, isFalse);
    }
    final field = _inRow('Crossfade', find.byType(TextField));
    expect(tester.widget<TextField>(field).enabled, isFalse);

    final semantics = tester.ensureSemantics();
    final data = tester.getSemantics(field).getSemanticsData();
    expect(data.flagsCollection.isEnabled, isNot(Tristate.isTrue));
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();

    final before = tester.widgetList(find.byType(MenuItemButton)).length;
    await tester.tap(field, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton).evaluate(), hasLength(before));
  });

  testWidgets('a stored value outside the presets still shows', (tester) async {
    await _openApp(
      tester,
      const AppSettings(libraryScan: LibraryScanPrefs(minFileSizeKb: 300)),
    );
    await _visit(tester, settingsLibraryRoute);

    final field = tester.widget<TextField>(
      _inRow('Minimum file size', find.byType(TextField)),
    );
    expect(field.controller!.text, '300 KB');
  });

  testWidgets('tapping every control changes nothing', (tester) async {
    await _openApp(tester, _stored);
    final before = container.read(settingsProvider);

    for (final page in _pages) {
      await _visit(tester, page);
      await _tapComingSoonControls(tester);
    }
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider), before);
    expect(
      find.byType(MenuItemButton).hitTestable(),
      findsNothing,
      reason: 'no menu opened',
    );
  });
}

/// Taps every control of the coming soon rows on the page shown.
Future<void> _tapComingSoonControls(WidgetTester tester) async {
  for (final row in _comingSoonRows()) {
    final controls = find.descendant(
      of: find.byElementPredicate((e) => e == row),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Switch ||
            w is FilterChip ||
            w is TextField ||
            w is FilledButton,
      ),
    );
    for (final control in controls.evaluate()) {
      await tester.tap(find.byWidget(control.widget), warnIfMissed: false);
      await tester.pump();
    }
  }
}
