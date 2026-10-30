import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    // Tall enough to build every section: the list is lazy.
    tester.view.physicalSize = const Size(1280, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(languageCode: 'en'),
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
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('the sections are in order, Lyrics between Library and Backup', (
    tester,
  ) async {
    await openSettings(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final titles = [
      l10n.settingsAppearance,
      l10n.settingsLibrary,
      l10n.settingsLyrics,
      l10n.settingsBackupRestore,
      l10n.settingsAdvanced,
      l10n.settingsAbout,
    ];
    final tops = [for (final t in titles) top(tester, t)];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: titles[i]);
    }
  });

  testWidgets('the lyrics rows are in the Lyrics section, not in Advanced', (
    tester,
  ) async {
    await openSettings(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final start = top(tester, l10n.settingsLyrics);
    final end = top(tester, l10n.settingsBackupRestore);
    for (final title in [
      l10n.settingsPreferEmbeddedLyrics,
      l10n.settingsAutoOnlineLyrics,
      l10n.settingsLyricsConsent,
      l10n.settingsSavedLyrics,
      l10n.settingsTranslationService,
      l10n.settingsTranslationTarget,
      l10n.settingsTranslationCache,
    ]) {
      final y = top(tester, title);
      expect(y, greaterThan(start), reason: title);
      expect(y, lessThan(end), reason: title);
    }
    // The lyrics rows come before the translation rows.
    expect(
      top(tester, l10n.settingsPreferEmbeddedLyrics),
      lessThan(top(tester, l10n.settingsTranslationService)),
    );
    expect(find.text('Find lyrics online automatically'), findsOneWidget);
    expect(find.textContaining('(LRCLIB)'), findsNothing);
  });
}
