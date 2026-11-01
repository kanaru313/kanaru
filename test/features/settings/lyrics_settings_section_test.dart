import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'settings_page_opener.dart';

void main() {
  Future<void> openSettings(
    WidgetTester tester, {
    String page = 'Playback',
    List<Override> overrides = const [],
  }) async {
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
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KanaruApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined).hitTestable().first);
    await tester.pumpAndSettle();
    await openSettingsPage(tester, page);
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  /// Top of the group headed [title]; the page title may repeat the word.
  double groupTop(WidgetTester tester, String title) => tester
      .getTopLeft(
        find.byWidgetPredicate((w) => w is SettingsSection && w.title == title),
      )
      .dy;

  testWidgets('the groups are in order: Playback, Lyrics, Translation', (
    tester,
  ) async {
    await openSettings(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final titles = [
      l10n.settingsGroupPlayback,
      l10n.settingsLyrics,
      l10n.settingsGroupTranslation,
    ];
    final tops = [for (final t in titles) groupTop(tester, t)];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: titles[i]);
    }
  });

  testWidgets('lyrics rows sit under Lyrics, translation rows under '
      'Translation', (tester) async {
    await openSettings(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final lyrics = groupTop(tester, l10n.settingsLyrics);
    final translation = groupTop(tester, l10n.settingsGroupTranslation);
    for (final title in [
      l10n.lyricsSourcesTitle,
      l10n.settingsPreferEmbeddedLyrics,
      l10n.settingsAutoOnlineLyrics,
      l10n.settingsLyricsConsent,
    ]) {
      final y = top(tester, title);
      expect(y, greaterThan(lyrics), reason: title);
      expect(y, lessThan(translation), reason: title);
    }
    for (final title in [
      l10n.settingsTranslationService,
      l10n.settingsTranslationTarget,
    ]) {
      expect(top(tester, title), greaterThan(translation), reason: title);
    }
    // The saved lyrics and translations are caches, not on this page.
    expect(find.text(l10n.settingsSavedLyrics), findsNothing);
    expect(find.text(l10n.settingsTranslationCache), findsNothing);
    expect(find.text('Find lyrics online automatically'), findsOneWidget);
    expect(find.textContaining('(LRCLIB)'), findsNothing);
  });

  testWidgets('the saved lyrics and translations are under Caches', (
    tester,
  ) async {
    await openSettings(tester, page: 'Data & storage');
    final l10n = lookupAppLocalizations(const Locale('en'));
    final caches = groupTop(tester, l10n.settingsGroupCaches);
    final logs = groupTop(tester, l10n.settingsGroupLogs);
    for (final title in [
      l10n.settingsSavedLyrics,
      l10n.settingsTranslationCache,
    ]) {
      final y = top(tester, title);
      expect(y, greaterThan(caches), reason: title);
      expect(y, lessThan(logs), reason: title);
    }
  });

  group('lyrics sources row', () {
    LyricsPluginRecord record(String id, String name, int at) =>
        LyricsPluginRecord(
          kind: PluginKind.lyrics,
          installId: id,
          name: name,
          version: 1,
          apiVersion: 1,
          hosts: const ['api.example.com'],
          config: const [],
          packageDir: '$id/v1-1',
          sourceKind: LyricsPluginSourceKind.file,
          sourceName: 'x.zip',
          installedAt: at,
          updatedAt: at,
        );

    List<Override> sources(List<LyricsSourcePrefRow> prefs) => [
      lyricsSourcesInputProvider.overrideWith(
        (ref) => Stream.value(
          LyricsSourcesInput([
            record('plugin-aaaaaaaaaaaa', 'NetEase', 1),
            record('plugin-bbbbbbbbbbbb', 'Kugou', 2),
          ], prefs),
        ),
      ),
    ];

    testWidgets('names the enabled sources in order and counts them', (
      tester,
    ) async {
      await openSettings(
        tester,
        overrides: sources(const [
          LyricsSourcePrefRow(
            providerId: 'plugin-bbbbbbbbbbbb',
            enabled: false,
            position: 3,
          ),
        ]),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.lyricsSourcesTitle), findsOneWidget);
      expect(find.text('LRCLIB, NetEase · 2 on'), findsOneWidget);
      // It sits at the top of the Lyrics section.
      expect(
        top(tester, l10n.lyricsSourcesTitle),
        lessThan(top(tester, l10n.settingsPreferEmbeddedLyrics)),
      );
    });

    testWidgets('says so when every source is off', (tester) async {
      await openSettings(
        tester,
        overrides: sources(const [
          LyricsSourcePrefRow(
            providerId: 'lrclib',
            enabled: false,
            position: 0,
          ),
          LyricsSourcePrefRow(
            providerId: 'plugin-aaaaaaaaaaaa',
            enabled: false,
            position: 1,
          ),
          LyricsSourcePrefRow(
            providerId: 'plugin-bbbbbbbbbbbb',
            enabled: false,
            position: 2,
          ),
        ]),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.lyricsSourcesRowNoneOn), findsOneWidget);
    });

    testWidgets('opens the sources page', (tester) async {
      await openSettings(tester, overrides: sources(const []));
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text('LRCLIB, NetEase, Kugou · 3 on'));
      await tester.pumpAndSettle();
      // The page's Get more plugins row is only on the sources page.
      expect(find.text(l10n.lyricsSourcesGetMore), findsOneWidget);
    });
  });
}
