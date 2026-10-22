import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_choice.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

/// Width of a settings row from which the control is built in full (a
/// segmented button rather than a dropdown); mirrors `setting_row.dart`.
const _wideRowFrom = 560.0;

void main() {
  // 820 to 940 px windows give 579 to 699 px rows next to the sidebar:
  // wide rows with little room, where the full controls get tight.
  // Tall enough to build every section: the list is lazy.
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

/// Opens Settings in a [size] window in [language] and checks that every
/// row fits, keeps its control on the title's line, and that all controls
/// are [settingControlHeight] tall as drawn.
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
  await tester.tap(find.byIcon(Icons.settings_outlined).hitTestable().first);
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);

  // Sections start at the same left edge whatever their rows' width.
  expect(
    tester.getTopLeft(find.text(l10n.settingsAbout)).dx,
    tester.getTopLeft(find.text(l10n.settingsAppearance)).dx,
  );

  // The rescan button, apart from the "Add folder" one.
  final rescanButton = find.ancestor(
    of: find.text(l10n.libraryRescan),
    matching: find.byType(FilledButton),
  );

  // The control of the row titled [label], found inside that row.
  Finder inRow(String label, Finder control) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(SettingRow)),
    matching: control,
  );

  // Every control sits on its label's line, at its right.
  // A row with a subtitle centres its control on the title and subtitle
  // together, so that block stands for the label there.
  for (final (label, control, subtitle) in [
    (l10n.settingsFolders, find.byType(FilledButton).first, null),
    (
      l10n.settingsRescanOnStartup,
      inRow(l10n.settingsRescanOnStartup, find.byType(Switch)),
      null,
    ),
    (l10n.settingsRescanLibrary, rescanButton, null),
    (
      l10n.listenHistoryRecord,
      inRow(l10n.listenHistoryRecord, find.byType(Switch)),
      l10n.listenHistoryRecordHint,
    ),
    (
      l10n.listenHistoryClear,
      inRow(l10n.listenHistoryClear, find.byType(FilledButton)),
      null,
    ),
    (l10n.settingsTheme, find.byType(SettingChoice<ThemePreference>), null),
    (l10n.settingsLanguage, find.byType(SettingDropdown<String>), null),
    (
      l10n.settingsTitleBar,
      find.byType(SettingChoice<TitleBarPreference>),
      null,
    ),
  ]) {
    final title = tester.getRect(find.text(label));
    final text = subtitle == null
        ? title
        : title.expandToInclude(tester.getRect(find.text(subtitle)));
    final rect = tester.getRect(control);
    expect(
      text.center.dy,
      inInclusiveRange(rect.top, rect.bottom),
      reason: '$label: control on the same line',
    );
    expect(rect.left, greaterThan(title.right), reason: label);
  }

  // Every control, whatever its kind, has the same height as drawn
  // (a wide row's control is never scaled down).
  final controls = [
    ...find.byType(FilledButton).evaluate(),
    ...find
        .byWidgetPredicate((w) => w is SegmentedButton || w is DropdownMenu)
        .evaluate(),
  ];
  expect(controls, hasLength(6), reason: 'three buttons and three choices');
  for (final control in controls) {
    expect(
      tester.getRect(find.byWidget(control.widget)).height,
      moreOrLessEquals(settingControlHeight),
      reason: '${control.widget.runtimeType}',
    );
  }

  // The rescan label is drawn inside its button on one line, however narrow
  // the button gets; at normal text size it also fits whole (no ellipsis).
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

  final rowWidth = tester.getSize(find.byType(SettingRow).first).width;
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

  // In narrow rows, compact selectors share one width, right edges lined
  // up, and the rescan button ends on the same edge.
  if (!wideRows) {
    final dropdowns = find
        .byWidgetPredicate((w) => w is DropdownMenu)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(dropdowns, hasLength(3));
    for (final rect in dropdowns.skip(1)) {
      expect(rect.width, dropdowns.first.width);
      expect(rect.right, dropdowns.first.right);
    }
    expect(tester.getRect(rescanButton).right, dropdowns.first.right);
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
