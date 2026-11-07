import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_choice.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/features/settings/settings_category_tile.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

/// Width of a settings row from which the control is built in full (a
/// segmented button rather than a dropdown); mirrors `setting_row.dart`.
const _wideRowFrom = 540.0;

void main() {
  // 820 to 940 px windows give 579 to 699 px rows next to the sidebar:
  // wide rows with little room, where the full controls get tight.
  // Tall enough to show a whole page.
  const sizes = [
    Size(480, 1200),
    Size(760, 1200),
    Size(820, 1200),
    Size(900, 1200),
    Size(940, 1200),
    Size(1280, 1200),
  ];
  const largeTextSizes = [Size(480, 1200), Size(900, 1200), Size(1280, 1200)];

  for (final language in ['en', 'vi']) {
    for (final size in sizes) {
      testWidgets(
        'settings fit a ${size.width.toInt()} px window in $language',
        (tester) => _checkLayout(tester, language, size),
      );
    }
    for (final size in largeTextSizes) {
      testWidgets(
        'settings fit a ${size.width.toInt()} px window in $language with '
        'large text',
        (tester) => _checkLayout(tester, language, size, textScale: 2),
      );
    }
  }
}

/// A row that must keep [control] on its label's line, at its right. A row
/// centres its control on the title and subtitle together, so that block
/// stands for the label.
typedef _Line = (String label, Finder control, String subtitle);

/// The control of the row titled [label], found inside that row.
Finder _inRow(String label, Finder control) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(SettingRow)),
  matching: control,
);

/// Opens Settings in a [size] window in [language] and checks the root and
/// each page: every row fits, keeps its control on the title's line, and
/// all controls are [settingControlHeight] tall as drawn.
Future<void> _checkLayout(
  WidgetTester tester,
  String language,
  Size size, {
  double textScale = 1,
}) async {
  final l10n = lookupAppLocalizations(Locale(language));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      initialSettingsProvider.overrideWithValue(
        AppSettings(languageCode: language),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(AppIcons.settingsOutlined).hitTestable().first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  // The root: seven tiles that fit the window.
  final tiles = find.byType(SettingsCategoryTile);
  expect(tiles, findsNWidgets(7));
  for (final tile in tiles.evaluate()) {
    final rect = tester.getRect(find.byWidget(tile.widget));
    expect(rect.right, lessThanOrEqualTo(size.width));
  }

  final router = container.read(routerProvider);
  Future<void> visit(String route) async {
    router.go(route);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: route);
    // Sections start at the same left edge whatever their rows' width.
    final lefts = {
      for (final e in find.byType(SettingsSection).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dx,
    };
    expect(lefts, hasLength(1), reason: route);
  }

  await visit(settingsAppearanceRoute);
  final rowWidth = tester.getSize(find.byType(SettingRow).first).width;
  // Chips wrap inside the window, however narrow.
  for (final label in [l10n.navFolders, l10n.settingsTabLanguages]) {
    final chip = tester.getRect(find.text(label).last);
    expect(chip.right, lessThanOrEqualTo(size.width), reason: label);
  }
  await _checkRows(
    tester,
    size,
    [
      (
        l10n.settingsTheme,
        find.byType(SettingChoice<ThemePreference>),
        l10n.settingsThemeHint,
      ),
      (
        l10n.settingsLanguage,
        _inRow(l10n.settingsLanguage, find.byType(SettingDropdown<String>)),
        l10n.settingsLanguageHint,
      ),
      (
        l10n.settingsFontScale,
        _inRow(l10n.settingsFontScale, find.byType(DropdownMenu<double>)),
        l10n.settingsFontScaleHint,
      ),
      (
        l10n.settingsTitleBar,
        find.byType(SettingChoice<TitleBarPreference>),
        l10n.settingsTitleBarHint,
      ),
    ],
    controls: _appearanceControls,
    dropdowns: _appearanceDropdowns,
  );
  await _checkThemeControl(
    tester,
    container,
    language,
    size,
    textScale,
    rowWidth,
  );

  await visit(settingsPlaybackRoute);
  await _checkRows(
    tester,
    size,
    [
      (
        l10n.settingsFadeOnPlay,
        _inRow(l10n.settingsFadeOnPlay, find.byType(DropdownMenu<int>)),
        l10n.settingsFadeOnPlayHint,
      ),
      (
        l10n.settingsFadeOnPause,
        _inRow(l10n.settingsFadeOnPause, find.byType(DropdownMenu<int>)),
        l10n.settingsFadeOnPauseHint,
      ),
      (
        l10n.listenHistoryRecord,
        _inRow(l10n.listenHistoryRecord, find.byType(Switch)),
        l10n.listenHistoryRecordHint,
      ),
      (
        l10n.settingsTranslationService,
        find.byType(SettingDropdown<TranslationServiceId>),
        l10n.settingsTranslationServicePluginHint,
      ),
      (
        l10n.settingsTranslationTarget,
        _inRow(
          l10n.settingsTranslationTarget,
          find.byWidgetPredicate((w) => w is DropdownMenu),
        ),
        l10n.settingsTranslationTargetHint,
      ),
      (
        l10n.settingsTranslationPrefetch,
        _inRow(
          l10n.settingsTranslationPrefetch,
          find.byWidgetPredicate((w) => w is DropdownMenu),
        ),
        l10n.settingsTranslationPrefetchHint,
      ),
    ],
    controls: _playbackControls,
    dropdowns: _playbackDropdowns,
  );

  await visit(settingsLibraryRoute);
  // The rescan button, apart from the "Add folder" one.
  final rescanButton = find.ancestor(
    of: find.text(l10n.libraryRescan),
    matching: find.byType(FilledButton),
  );
  await _checkRows(
    tester,
    size,
    [
      (
        l10n.settingsFolders,
        find.byType(FilledButton).first,
        l10n.settingsFoldersHint,
      ),
      (
        l10n.settingsRescanOnStartup,
        _inRow(l10n.settingsRescanOnStartup, find.byType(Switch)),
        l10n.settingsRescanOnStartupHint,
      ),
      (
        l10n.settingsRescanLibrary,
        rescanButton,
        l10n.settingsRescanLibraryHint,
      ),
      (
        l10n.settingsRespectNomedia,
        _inRow(l10n.settingsRespectNomedia, find.byType(Switch)),
        l10n.settingsRespectNomediaHint,
      ),
      (
        l10n.separatorsArtistsTitle,
        _inRow(l10n.separatorsArtistsTitle, find.byType(FilledButton)),
        '${l10n.separatorsArtistsHint}\n${l10n.separatorsSummary(defaultArtistSeparators.length, 1)}',
      ),
      (
        l10n.separatorsGenresTitle,
        _inRow(l10n.separatorsGenresTitle, find.byType(FilledButton)),
        '${l10n.separatorsGenresHint}\n${l10n.separatorsSummary(1, 0)}',
      ),
      (
        l10n.settingsMinFileSize,
        _inRow(l10n.settingsMinFileSize, find.byType(DropdownMenu<int>)),
        l10n.settingsMinFileSizeHint,
      ),
    ],
    controls: _libraryControls,
    dropdowns: _libraryDropdowns,
  );
  _checkRescanLabel(tester, l10n, rescanButton, textScale);
  // Chips wrap inside the window, however narrow.
  for (final label in [l10n.settingsAlbumGroupYear]) {
    final chip = tester.getRect(find.text(label).last);
    expect(chip.right, lessThanOrEqualTo(size.width), reason: label);
  }
  if (rowWidth < _wideRowFrom) {
    // In narrow rows the rescan button ends on the dropdowns' right edge.
    final edge = tester.getRect(find.byType(DropdownMenu<int>).first).right;
    expect(tester.getRect(rescanButton).right, edge);
  }

  await visit(settingsDataRoute);
  await _checkRows(
    tester,
    size,
    [
      (
        l10n.settingsClearCoverCache,
        _inRow(l10n.settingsClearCoverCache, find.byType(FilledButton)),
        l10n.settingsClearCoverCacheHint,
      ),
      (
        l10n.settingsTranslationCache,
        _inRow(l10n.settingsTranslationCache, find.byType(FilledButton)),
        l10n.translationCacheEmpty,
      ),
      (
        l10n.settingsSavedLyrics,
        _inRow(l10n.settingsSavedLyrics, find.byType(FilledButton)),
        l10n.settingsSavedLyricsNone,
      ),
    ],
    controls: _dataControls,
    dropdowns: _dataDropdowns,
  );

  await visit(settingsAdvancedRoute);
  await _checkRows(
    tester,
    size,
    [
      (
        l10n.settingsOpenLogFolder,
        _inRow(l10n.settingsOpenLogFolder, find.byType(FilledButton)),
        l10n.settingsOpenLogFolderHint,
      ),
      (
        l10n.listenHistoryClear,
        _inRow(l10n.listenHistoryClear, find.byType(FilledButton)),
        l10n.settingsClearListenHistoryHint,
      ),
      (
        l10n.settingsResetAllTitle,
        _inRow(l10n.settingsResetAllTitle, find.byType(FilledButton)),
        l10n.settingsResetAllHint,
      ),
    ],
    controls: _advancedControls,
    dropdowns: _advancedDropdowns,
  );

  await visit(settingsAboutRoute);
  expect(tester.takeException(), isNull);
}

// Counts of controls on each page (buttons, choices and dropdowns) and, in
// narrow rows where choices are dropdowns too, of dropdowns alone, so a control that goes missing or appears twice is caught.
const _appearanceControls = 4;
const _appearanceDropdowns = 4;
const _playbackControls = 7;
const _playbackDropdowns = 7;
const _libraryControls = 7;
const _libraryDropdowns = 2;
const _dataControls = 4;
const _dataDropdowns = 0;
const _advancedControls = 8;
const _advancedDropdowns = 3;

/// Checks the rows of the page shown: every control sits on its label's
/// line at its right, all [controls] are [settingControlHeight] tall as drawn
/// (a wide row's control is never scaled down), and in narrow rows the
/// compact selectors share one width with their right edges lined up.
Future<void> _checkRows(
  WidgetTester tester,
  Size size,
  List<_Line> lines, {
  required int controls,
  required int dropdowns,
}) async {
  for (final (label, control, subtitle) in lines) {
    // `.last`: the sidebar can list the same word (Languages) before the page.
    final title = tester.getRect(find.text(label).last);
    final text = title.expandToInclude(tester.getRect(find.text(subtitle)));
    final rect = tester.getRect(control);
    expect(
      text.center.dy,
      inInclusiveRange(rect.top, rect.bottom),
      reason: '$label: control on the same line',
    );
    expect(rect.left, greaterThan(title.right), reason: label);
  }

  final all = [
    ...find.byType(FilledButton).evaluate(),
    ...find
        .byWidgetPredicate((w) => w is SegmentedButton || w is DropdownMenu)
        .evaluate(),
  ];
  expect(all, hasLength(controls));
  for (final control in all) {
    expect(
      tester.getRect(find.byWidget(control.widget)).height,
      moreOrLessEquals(settingControlHeight),
      reason: '${control.widget.runtimeType}',
    );
  }

  final rowWidth = tester.getSize(find.byType(SettingRow).first).width;
  final rects = find
      .byWidgetPredicate((w) => w is DropdownMenu)
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)))
      .toList();
  if (rowWidth >= _wideRowFrom) return;
  // Narrow rows: every choice is a dropdown too.
  expect(rects, hasLength(dropdowns));
  if (rects.isEmpty) return;
  // The listen threshold row splits the compact width between its time and
  // share dropdowns; every other row has one.
  bool shared(Rect r) => rects.where((o) => o.top == r.top).length > 1;
  final single = rects.where((r) => !shared(r)).toList();
  final paired = rects.where(shared).toList();
  for (final rect in single.skip(1)) {
    expect(rect.width, single.first.width);
    expect(rect.right, single.first.right);
  }
  if (paired.isNotEmpty) {
    expect(paired, hasLength(2));
    expect(paired.first.width, paired.last.width);
    expect(paired.first.right, lessThanOrEqualTo(paired.last.left));
    expect(paired.last.right, single.first.right);
    expect(paired.first.left, greaterThanOrEqualTo(single.first.left));
  }
}

/// The rescan label is drawn inside its button on one line, however narrow
/// the button gets; at normal text size it also fits whole (no ellipsis).
void _checkRescanLabel(
  WidgetTester tester,
  AppLocalizations l10n,
  Finder rescanButton,
  double textScale,
) {
  final rescan = tester.getRect(rescanButton);
  final rescanLabel = find.descendant(
    of: rescanButton,
    matching: find.text(l10n.libraryRescan),
  );
  final labelRect = tester.getRect(rescanLabel);
  expect(labelRect.left, greaterThanOrEqualTo(rescan.left));
  expect(labelRect.right, lessThanOrEqualTo(rescan.right));
  expect(labelRect.top, greaterThanOrEqualTo(rescan.top));
  expect(labelRect.bottom, lessThanOrEqualTo(rescan.bottom));
  final paragraph = tester.renderObject<RenderParagraph>(rescanLabel);
  if (textScale == 1) {
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'rescan label cut short',
    );
  }
}

/// The theme control is the full segmented one in a roomy row, the compact
/// dropdown in a narrow one, never both; choosing Dark and a title bar
/// works from either.
Future<void> _checkThemeControl(
  WidgetTester tester,
  ProviderContainer container,
  String language,
  Size size,
  double textScale,
  double rowWidth,
) async {
  final l10n = lookupAppLocalizations(Locale(language));
  final wideRows = rowWidth >= _wideRowFrom;
  final theme = find.byType(SettingChoice<ThemePreference>);
  final segmented = find.descendant(
    of: theme,
    matching: find.byType(SegmentedButton<ThemePreference>),
  );
  final dropdown = find.descendant(
    of: theme,
    matching: find.byType(DropdownMenu<ThemePreference>),
  );
  if (!wideRows) {
    // Narrow rows always ask for the compact control.
    expect(segmented, findsNothing);
    expect(dropdown, findsOneWidget);
  } else if (language == 'en' && size.width >= 1280 && textScale == 1) {
    // The full control fits a roomy row.
    expect(segmented, findsOneWidget);
    expect(dropdown, findsNothing);
  } else {
    // A wide row shows the full control only when it fits, else the
    // compact one; never both, never a shrunk one.
    expect(
      segmented.evaluate().length + dropdown.evaluate().length,
      1,
      reason: 'one theme control',
    );
  }
  if (size.width > 760 && size.width < 1280) {
    expect(
      rowWidth,
      inInclusiveRange(_wideRowFrom, 700),
      reason: 'a mid window gives a tight wide row',
    );
  }

  await tester.ensureVisible(theme);
  await tester.pumpAndSettle();
  await _choose(tester, theme, l10n.settingsThemeDark);
  expect(container.read(settingsProvider).theme, ThemePreference.dark);

  final titleBar = find.byType(SettingChoice<TitleBarPreference>);
  await tester.ensureVisible(titleBar);
  await tester.pumpAndSettle();
  expect(titleBar.hitTestable(), findsOneWidget);
  await _choose(tester, titleBar, l10n.settingsTitleBarNone);
  expect(container.read(settingsProvider).titleBar, TitleBarPreference.none);
  expect(tester.takeException(), isNull);
}

/// Picks an option of a [SettingChoice] by its label, from its segment or
/// its dropdown menu.
Future<void> _choose(WidgetTester tester, Finder choice, String label) async {
  final segments = find.descendant(
    of: choice,
    matching: find.byWidgetPredicate((w) => w is SegmentedButton),
  );
  if (segments.evaluate().isNotEmpty) {
    await tester.tap(find.descendant(of: segments, matching: find.text(label)));
  } else {
    await tester.tap(
      find.descendant(of: choice, matching: find.byType(TextField)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(MenuItemButton),
            matching: find.text(label),
          )
          .hitTestable(),
    );
  }
  await tester.pumpAndSettle();
}
