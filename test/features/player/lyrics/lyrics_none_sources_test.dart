import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_status_states.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/fake_lyrics_provider.dart';

const _uri = '/m/song.flac';
const _plugin = 'plugin-aaaaaaaaaaaa';

/// A provider that reads like a plugin: its id is an install id.
class _Named extends FakeLyricsProvider {
  _Named(String id, this._name) : super(id: id);

  final String _name;

  @override
  String get displayName => _name;
}

void main() {
  late Directory logDir;

  setUp(() {
    logDir = Directory.systemTemp.createTempSync('kanaru-none-logs');
    addTearDown(() => logDir.deleteSync(recursive: true));
  });

  /// [LyricsNoneView] over the sources in [providers] (the enabled ones, in
  /// order) with a library and automatic lookups [autoOn].
  Future<void> pump(
    WidgetTester tester,
    LyricsNone none,
    List<FakeLyricsProvider> providers, {
    bool library = true,
    bool autoOn = false,
    Map<String, LyricsSourceName>? names,
  }) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsProvidersProvider.overrideWithValue([
            for (final p in providers) LyricsProviderRegistration(p),
          ]),
          libraryDatabaseProvider.overrideWithValue(library ? db : null),
          playingLyricsSourceProvider.overrideWithValue(null),
          // Names from the given sources, so no plugin table is read.
          lyricsSourceNamesProvider.overrideWithValue(
            names ??
                {
                  for (final p in providers)
                    p.id: LyricsSourceName(displayName: p.displayName),
                },
          ),
          lyricsPluginLogDirProvider.overrideWithValue(logDir),
          initialSettingsProvider.overrideWithValue(
            AppSettings(
              onlineLyrics: OnlineLyricsPrefs(
                autoFetch: autoOn,
                manualConsent: autoOn,
                autoConsent: autoOn,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LyricsNoneView(none: none)),
        ),
      ),
    );
    await tester.pump();
  }

  /// A test that unmounts at the end, so the library streams the view's
  /// providers opened can close their timers.
  void statusTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });

  const noLyrics = LyricsNone(_uri, LyricsNoneReason.noLyrics);
  const notFound = LyricsNone(_uri, LyricsNoneReason.notFound);
  final findOnline = find.text('Find lyrics online…');
  final findAuto = find.text('Find lyrics automatically');

  group('the online buttons follow the enabled sources', () {
    statusTest('a plugin as the only enabled source still offers them', (
      tester,
    ) async {
      await pump(tester, noLyrics, [_Named(_plugin, 'NetEase')]);
      expect(findOnline, findsOneWidget);
      expect(findAuto, findsOneWidget);
    });

    statusTest('no enabled source offers none', (tester) async {
      await pump(tester, noLyrics, const [], autoOn: false);
      expect(findOnline, findsNothing);
      expect(findAuto, findsNothing);
    });

    statusTest('no enabled source with automatic on offers none', (
      tester,
    ) async {
      await pump(tester, notFound, const [], autoOn: true);
      expect(find.byType(FilledButton), findsNothing);
    });

    statusTest('a plugin first and LRCLIB second still offer them', (
      tester,
    ) async {
      await pump(tester, noLyrics, [
        _Named(_plugin, 'NetEase'),
        FakeLyricsProvider(id: 'lrclib'),
      ]);
      expect(findOnline, findsOneWidget);
    });
  });

  group('the empty-state text', () {
    statusTest('names the one enabled source, a plugin', (tester) async {
      await pump(tester, notFound, [_Named(_plugin, 'NetEase')]);
      expect(find.text('No lyrics found on NetEase'), findsOneWidget);
    });

    statusTest('names every enabled source, not just the first', (
      tester,
    ) async {
      await pump(tester, notFound, [
        _Named(_plugin, 'NetEase'),
        _Named('plugin-bbbbbbbbbbbb', 'QQ Music'),
      ]);
      expect(find.text('No lyrics found on NetEase, QQ Music'), findsOneWidget);
    });

    statusTest('tells two sources of one name apart by author', (tester) async {
      await pump(
        tester,
        notFound,
        [_Named(_plugin, 'NetEase'), _Named('plugin-bbbbbbbbbbbb', 'NetEase')],
        names: {
          _plugin: const LyricsSourceName(
            displayName: 'NetEase',
            author: 'hieu05',
          ),
          'plugin-bbbbbbbbbbbb': const LyricsSourceName(
            displayName: 'NetEase',
            author: 'other-dev',
          ),
        },
      );
      expect(
        find.text('No lyrics found on NetEase · hieu05, NetEase · other-dev'),
        findsOneWidget,
      );
    });
  });

  group('the error banner', () {
    const failed = LyricsNone(
      _uri,
      LyricsNoneReason.error,
      failure: LyricsFetchKind.network,
    );

    statusTest('names the one enabled plugin and offers its log', (
      tester,
    ) async {
      File('${logDir.path}/$_plugin.jsonl').writeAsStringSync('{}\n');
      await pump(tester, failed, [_Named(_plugin, 'NetEase')]);
      expect(find.text("Couldn't reach NetEase"), findsOneWidget);
      expect(find.text('View log'), findsOneWidget);
    });

    statusTest('has no View log when only LRCLIB runs', (tester) async {
      await pump(tester, failed, [FakeLyricsProvider(id: 'lrclib')]);
      expect(find.text('View log'), findsNothing);
    });

    statusTest('has no View log with LRCLIB beside one plugin', (tester) async {
      File('${logDir.path}/$_plugin.jsonl').writeAsStringSync('{}\n');
      await pump(tester, failed, [
        FakeLyricsProvider(id: 'lrclib'),
        _Named(_plugin, 'NetEase'),
      ]);
      expect(find.text('View log'), findsNothing);
    });

    statusTest('has no View log when two plugins could have failed', (
      tester,
    ) async {
      File('${logDir.path}/$_plugin.jsonl').writeAsStringSync('{}\n');
      await pump(tester, failed, [
        _Named(_plugin, 'NetEase'),
        _Named('plugin-bbbbbbbbbbbb', 'QQ Music'),
      ]);
      expect(find.text('View log'), findsNothing);
    });
  });
}
