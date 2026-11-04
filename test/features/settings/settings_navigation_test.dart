import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/about_settings_section.dart';
import 'package:kanaru/features/settings/appearance_layout_setting_rows.dart';
import 'package:kanaru/features/settings/appearance_text_setting_rows.dart';
import 'package:kanaru/features/settings/appearance_theme_setting_rows.dart';
import 'package:kanaru/features/settings/audio_engine_setting_rows.dart';
import 'package:kanaru/features/settings/backup_settings_section.dart';
import 'package:kanaru/features/settings/cover_cache_setting_rows.dart';
import 'package:kanaru/features/settings/danger_zone_setting_rows.dart';
import 'package:kanaru/features/settings/excluded_folders_list.dart';
import 'package:kanaru/features/settings/folder_watch_row.dart';
import 'package:kanaru/features/settings/interface_setting_rows.dart';
import 'package:kanaru/features/settings/library_folders_list.dart';
import 'package:kanaru/features/settings/library_organization_setting_rows.dart';
import 'package:kanaru/features/settings/library_rescan_setting_rows.dart';
import 'package:kanaru/features/settings/library_scan_setting_rows.dart';
import 'package:kanaru/features/settings/library_stats_row.dart';
import 'package:kanaru/features/settings/listen_history_setting_rows.dart';
import 'package:kanaru/features/settings/log_folder_setting_row.dart';
import 'package:kanaru/features/settings/lyrics_setting_rows.dart';
import 'package:kanaru/features/settings/lyrics_settings_section.dart';
import 'package:kanaru/features/settings/lyrics_translation_setting_rows.dart';
import 'package:kanaru/features/settings/online_lyrics_cache_setting_row.dart';
import 'package:kanaru/features/settings/online_lyrics_consent_setting_row.dart';
import 'package:kanaru/features/settings/playback_setting_rows.dart';
import 'package:kanaru/features/settings/playback_settings_page.dart';
import 'package:kanaru/features/settings/privacy_network_setting_rows.dart';
import 'package:kanaru/features/settings/scan_stats_rows.dart';
import 'package:kanaru/features/settings/separator_setting_rows.dart';
import 'package:kanaru/features/settings/settings_category_tile.dart';
import 'package:kanaru/features/settings/settings_focus.dart';
import 'package:kanaru/features/settings/translation_cache_setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'settings_page_opener.dart';

late ProviderContainer container;

/// Pumps the whole app on the Settings root in a window that is not tall, so
/// pages scroll.
Future<void> _pumpRoot(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(languageCode: 'en'),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      initialSettingsProvider.overrideWithValue(settings),
      ...overrides,
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

String _location() =>
    container.read(routerProvider).routeInformationProvider.value.uri.path;

Future<void> _back(WidgetTester tester) async {
  container.read(navigationHistoryProvider.notifier).back();
  await tester.pumpAndSettle();
}

/// Row groups that must each appear exactly once across the six pages.
final _rowTypes = <Type>[
  AppearanceThemeSettingRows,
  AppearanceTextSettingRows,
  AppearanceLayoutSettingRows,
  InterfaceSettingRows,
  PlaybackSettingRows,
  ListenHistorySettingRows,
  LyricsSettingsSection,
  LyricsSettingRows,
  LyricsTranslationSettingRows,
  LibraryStatsRow,
  ScanStatsRows,
  LibraryFoldersList,
  ExcludedFoldersList,
  LibraryRescanSettingRows,
  BackupSettingsSection,
  CoverCacheSettingRows,
  OnlineLyricsCacheSettingRow,
  TranslationCacheSettingRow,
  AudioEngineSettingRows,
  FolderWatchRow,
  LibraryScanSettingRows,
  LibraryOrganizationSettingRows,
  SeparatorSettingRows,
  PrivacyNetworkSettingRows,
  OnlineLyricsConsentSettingRow,
  LogFolderSettingRow,
  DangerZoneSettingRows,
  AboutSettingsSection,
];

const _pageRoutes = [
  settingsAppearanceRoute,
  settingsPlaybackRoute,
  settingsLibraryRoute,
  settingsDataRoute,
  settingsAdvancedRoute,
  settingsAboutRoute,
];

/// How many of each of [types] the five pages build, one page at a time.
Future<Map<Type, int>> _countRows(WidgetTester tester, List<Type> types) async {
  final counts = {for (final type in types) type: 0};
  for (final route in _pageRoutes) {
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    for (final type in types) {
      counts[type] = counts[type]! + find.byType(type).evaluate().length;
    }
  }
  return counts;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('the root lists seven tiles in order, with descriptions', (
    tester,
  ) async {
    await _pumpRoot(tester);

    final tiles = tester
        .widgetList<SettingsCategoryTile>(find.byType(SettingsCategoryTile))
        .toList();
    expect(
      [for (final t in tiles) t.title],
      [
        l10n.settingsAppearance,
        l10n.settingsPlayback,
        l10n.settingsLibrary,
        l10n.settingsPlugins,
        l10n.settingsDataStorage,
        l10n.settingsAdvanced,
        l10n.settingsAbout,
      ],
    );
    expect(
      [for (final t in tiles) t.description],
      [
        l10n.settingsAppearanceDescription,
        l10n.settingsPlaybackDescription,
        l10n.settingsLibraryDescription,
        l10n.settingsPluginsDescription,
        l10n.settingsDataStorageDescription,
        l10n.settingsAdvancedDescription,
        l10n.settingsAboutDescription,
      ],
    );
    expect(_location(), settingsRoute);
  });

  testWidgets('each tile opens its page, and back returns to the root', (
    tester,
  ) async {
    await _pumpRoot(tester);

    for (final (tile, route) in [
      (l10n.settingsAppearance, settingsAppearanceRoute),
      (l10n.settingsPlayback, settingsPlaybackRoute),
      (l10n.settingsLibrary, settingsLibraryRoute),
      (l10n.settingsDataStorage, settingsDataRoute),
      (l10n.settingsAdvanced, settingsAdvancedRoute),
      (l10n.settingsAbout, settingsAboutRoute),
    ]) {
      await openSettingsPage(tester, tile);
      expect(_location(), route, reason: tile);
      expect(find.text(tile), findsWidgets, reason: tile);

      await _back(tester);
      expect(_location(), settingsRoute, reason: tile);
      expect(find.byType(SettingsCategoryTile), findsNWidgets(7));
    }
  });

  testWidgets('every row group appears exactly once across the pages', (
    tester,
  ) async {
    await _pumpRoot(tester);

    final counts = await _countRows(tester, _rowTypes);

    for (final MapEntry(key: type, value: count) in counts.entries) {
      expect(count, 1, reason: '$type');
    }
  });

  testWidgets('back from the sources page keeps the Playback page and its '
      'scroll', (tester) async {
    await _pumpRoot(
      tester,
      overrides: [
        lyricsSourcesInputProvider.overrideWith(
          (ref) => Stream.value(
            const LyricsSourcesInput(<LyricsPluginRecord>[], []),
          ),
        ),
      ],
    );
    await openSettingsPage(tester, l10n.settingsPlayback);
    final scrollable = find
        .descendant(
          of: find.byType(PlaybackSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final stateBefore = tester.state<ScrollableState>(scrollable);

    final row = find.text(l10n.lyricsSourcesTitle);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final offset = stateBefore.position.pixels;
    expect(offset, greaterThan(0), reason: 'the page scrolled to the row');

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(_location(), lyricsSourcesRoute);

    await _back(tester);
    expect(_location(), settingsPlaybackRoute);
    final stateAfter = tester.state<ScrollableState>(scrollable);
    expect(identical(stateAfter, stateBefore), isTrue);
    expect(stateAfter.position.pixels, offset);
  });

  testWidgets('the save warning shows on the root and on all five pages', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_nav_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/settings.json';
    File(path).writeAsStringSync('{"version": 99}');
    await _pumpRoot(
      tester,
      overrides: [
        settingsFileProvider.overrideWithValue(SettingsFile(path)..load()),
      ],
    );
    final warning = find.text(l10n.settingsReadOnly(path));

    expect(warning, findsOneWidget, reason: 'root');
    for (final route in _pageRoutes) {
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget, reason: route);
    }
  });

  testWidgets('the Plugins tile is on the root', (tester) async {
    await _pumpRoot(tester);

    // Its navigation is tested with the store: opening it here would build
    // the real store, which reads the repositories.
    expect(
      find.widgetWithText(SettingsCategoryTile, l10n.settingsPlugins),
      findsOneWidget,
    );
  });

  group('links with a focus', () {
    final link = settingsFocusLocation(SettingsAnchor.playbackTranslation);

    bool translationPulsing(WidgetTester tester) {
      final target = find.byWidgetPredicate(
        (w) =>
            w is SettingsFocusTarget &&
            w.anchor == SettingsAnchor.playbackTranslation,
      );
      return tester
              .widget<Material>(
                find
                    .descendant(of: target, matching: find.byType(Material))
                    .first,
              )
              .type ==
          MaterialType.canvas;
    }

    Future<void> afterSettleDelay(WidgetTester tester) async {
      await tester.pump(settingsFocusSettleDelay);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> finishPulse(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 3));

    testWidgets('open Playback with the group pulsing, then a plain URL', (
      tester,
    ) async {
      await _pumpRoot(tester);

      container.read(routerProvider).go(link);
      await tester.pump();
      await tester.pump();

      expect(_location(), settingsPlaybackRoute);
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        settingsPlaybackRoute,
      );
      await afterSettleDelay(tester);
      expect(translationPulsing(tester), isTrue);
      await finishPulse(tester);
    });

    testWidgets('going away and back never pulses again', (tester) async {
      await _pumpRoot(tester);
      container.read(routerProvider).go(link);
      await tester.pump();
      await afterSettleDelay(tester);
      await finishPulse(tester);

      container.read(routerProvider).go('/songs');
      await tester.pumpAndSettle();
      await _back(tester);
      await afterSettleDelay(tester);

      expect(_location(), settingsPlaybackRoute);
      expect(translationPulsing(tester), isFalse);
      expect(
        container.read(navigationHistoryProvider).entries,
        everyElement(isNot(contains('focus'))),
      );
    });

    testWidgets('the same link twice pulses twice, also on the open page', (
      tester,
    ) async {
      await _pumpRoot(tester);
      container.read(routerProvider).go(link);
      await tester.pump();
      await afterSettleDelay(tester);
      expect(translationPulsing(tester), isTrue);
      await finishPulse(tester);
      expect(translationPulsing(tester), isFalse);

      container.read(routerProvider).go(link);
      await tester.pump();
      await afterSettleDelay(tester);

      expect(translationPulsing(tester), isTrue);
      await finishPulse(tester);
    });
  });
}
