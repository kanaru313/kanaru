import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_data_stats_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/lyrics_plugin_store_routes.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_routes.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

/// Id of the first test plugin.
const idA = 'plugin-aaaaaaaaaaaa';

/// Id of the second test plugin.
const idB = 'plugin-bbbbbbbbbbbb';

LyricsPluginRecord testRecord(
  String id, {
  String name = 'Demo',
  String? author = 'someone',
  List<PluginConfigField> config = const [],
  List<String> hosts = const ['api.example.com'],
  LyricsPluginSourceKind kind = LyricsPluginSourceKind.file,
  String sourceName = 'demo.zip',
  String? repoUrl,
  String? description,
  int installedAt = 1000,
}) => LyricsPluginRecord(
  installId: id,
  name: name,
  author: author,
  description: description,
  version: 3,
  apiVersion: 1,
  hosts: hosts,
  config: config,
  packageDir: '$id/v3-1',
  sourceKind: kind,
  sourceName: sourceName,
  repoUrl: repoUrl,
  installedAt: installedAt,
  updatedAt: installedAt,
);

/// A controller that records what the page asks of it.
class FakePlugins extends Fake implements LyricsPluginsController {
  final reorders = <List<String>>[];
  final enabled = <(String, bool)>[];
  final configWrites = <(String, String, Object?)>[];
  final uninstalls = <String>[];
  final storageClears = <String>[];
  final lyricsClears = <String>[];
  PluginConfigWrite configResult = PluginConfigWrite.written;
  LyricsPluginWrite storageResult = LyricsPluginWrite.written;
  Object? reorderError;
  Object? uninstallError;
  Object? storedError;

  /// When set, `uninstall` waits for it.
  Completer<void>? uninstallGate;

  /// When set, `setConfigValue` waits for it (once per call).
  Completer<void>? configGate;
  Map<String, Object?> stored = {};
  Set<String> secrets = {};
  bool fallback = false;

  @override
  Future<({List<String> written, List<String> skipped})> reorder(
    List<String> ids,
  ) async {
    reorders.add(ids);
    if (reorderError != null) throw reorderError!;
    return (written: ids, skipped: const <String>[]);
  }

  @override
  Future<LyricsPluginWrite> setEnabled(String installId, bool on) async {
    enabled.add((installId, on));
    return LyricsPluginWrite.written;
  }

  @override
  Future<PluginConfigWrite> setConfigValue(
    String installId,
    String key,
    Object? value,
  ) async {
    configWrites.add((installId, key, value));
    final gate = configGate;
    if (gate != null) await gate.future;
    return configResult;
  }

  @override
  Future<Map<String, Object?>> storedConfig(String installId) async {
    if (storedError != null) throw storedError!;
    return stored;
  }

  @override
  Future<bool> hasSecret(String installId, String key) async =>
      secrets.contains(key);

  @override
  Future<bool> secretsUsingFallback() async => fallback;

  @override
  Future<LyricsPluginUninstall> uninstall(String installId) async {
    uninstalls.add(installId);
    await uninstallGate?.future;
    if (uninstallError != null) throw uninstallError!;
    return LyricsPluginUninstall.deleted;
  }

  @override
  Future<LyricsPluginWrite> clearStorage(String installId) async {
    storageClears.add(installId);
    return storageResult;
  }

  @override
  Future<int> clearSavedLyrics(String installId) async {
    lyricsClears.add(installId);
    return 1;
  }
}

/// Opens the sources routes (with the plugin store's pages when [withStore]),
/// nested under a `/settings` page like the app's
/// router, inside a shell with a [Scaffold] (snackbars need one).
Future<GoRouter> pumpSources(
  WidgetTester tester, {
  List<LyricsPluginRecord> records = const [],
  List<LyricsSourcePrefRow> prefs = const [],
  FakePlugins? plugins,
  PluginDataStats stats = (storageBytes: 0, foundCount: 0, textBytes: 0),
  String location = lyricsSourcesRoute,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  Stream<LyricsSourcesInput>? input,
  bool withStore = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Text('settings page'),
            routes: lyricsSourcesRoutesWith(
              children: withStore ? lyricsStoreRoutes : const [],
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(plugins),
        lyricsSourcesInputProvider.overrideWith(
          (ref) => input ?? Stream.value(LyricsSourcesInput(records, prefs)),
        ),
        pluginDataStatsProvider.overrideWith((ref, id) async => stats),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The strings of the English locale.
AppLocalizations get en => lookupAppLocalizations(const Locale('en'));

/// The strings of the Vietnamese locale.
AppLocalizations get vi => lookupAppLocalizations(const Locale('vi'));

/// Presses Alt + [key] on whatever has focus.
Future<void> altKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pump();
}
