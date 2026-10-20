import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_choice.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  const sizes = [Size(480, 800), Size(760, 800), Size(1280, 800)];

  for (final language in ['en', 'vi']) {
    for (final size in sizes) {
      testWidgets(
        'settings fit a ${size.width.toInt()} px window in $language',
        (tester) async {
          final l10n = lookupAppLocalizations(Locale(language));
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
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
            UncontrolledProviderScope(
              container: container,
              child: const KanaruApp(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byIcon(Icons.settings_outlined).hitTestable().first,
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Sections start at the same left edge whatever their rows' width.
          expect(
            tester.getTopLeft(find.text(l10n.settingsAbout)).dx,
            tester.getTopLeft(find.text(l10n.settingsAppearance)).dx,
          );

          // Every control sits on its label's line, at its right.
          for (final (label, control) in [
            (l10n.settingsRescanLibrary, find.byType(FilledButton)),
            (l10n.settingsTheme, find.byType(SettingChoice<ThemePreference>)),
            (l10n.settingsLanguage, find.byType(SettingDropdown<String>)),
            (
              l10n.settingsTitleBar,
              find.byType(SettingChoice<TitleBarPreference>),
            ),
          ]) {
            final title = tester.getRect(find.text(label));
            final rect = tester.getRect(control);
            expect(
              title.center.dy,
              inInclusiveRange(rect.top, rect.bottom),
              reason: '$label: control on the same line',
            );
            expect(rect.left, greaterThan(title.right), reason: label);
          }

          final wideRows = size.width >= 1280;
          final theme = find.byType(SettingChoice<ThemePreference>);
          expect(
            find.descendant(
              of: theme,
              matching: find.byType(SegmentedButton<ThemePreference>),
            ),
            wideRows ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: theme,
              matching: find.byType(DropdownMenu<ThemePreference>),
            ),
            wideRows ? findsNothing : findsOneWidget,
          );

          // Compact selectors share one width, right edges lined up, and
          // the rescan button ends on the same edge.
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
            expect(
              tester.getRect(find.byType(FilledButton)).right,
              dropdowns.first.right,
            );
          }

          await _choose(tester, theme, l10n.settingsThemeDark);
          expect(container.read(settingsProvider).theme, ThemePreference.dark);

          final titleBar = find.byType(SettingChoice<TitleBarPreference>);
          await tester.ensureVisible(titleBar);
          await tester.pumpAndSettle();
          expect(titleBar.hitTestable(), findsOneWidget);
          await _choose(tester, titleBar, l10n.settingsTitleBarNone);
          expect(
            container.read(settingsProvider).titleBar,
            TitleBarPreference.none,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
