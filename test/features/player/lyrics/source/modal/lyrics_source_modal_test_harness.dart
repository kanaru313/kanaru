import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/playing_local_lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/source/modal/lyrics_source_modal.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/player/fake_audio_backend.dart';
import '../../fake_playing_lyrics_resolution.dart';
import 'lyrics_source_modal_fixtures.dart';

export '../../fake_playing_lyrics_resolution.dart';
export 'lyrics_source_modal_fixtures.dart';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

/// The scaffold that opens the modal, under its own messenger.
final openerScaffold = GlobalKey();

class SourceModalHarness {
  SourceModalHarness(this.container, this.resolution, this.log, this.router);

  final ProviderContainer container;
  final FakePlayingLyricsResolution resolution;
  final List<String> log;
  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Opens the lyrics source modal over a recording router. [records] are the
/// installed lyrics plugins and [disabled] the ids of those switched off;
/// [loaded] false keeps the source list unread and [loadFails] errors it.
Future<SourceModalHarness> pumpSourceModal(
  WidgetTester tester,
  LyricsSourceResolution initial, {
  List<LyricsPluginRecord> records = const [],
  Set<String> disabled = const {},
  bool autoAllowed = true,
  bool library = true,
  bool loaded = true,
  bool loadFails = false,
  bool autoSearchable = true,
  bool failChoose = false,
  Lyrics? ownLyrics,
  Size size = const Size(1000, 900),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final log = <String>[];
  final resolution = FakePlayingLyricsResolution(initial);
  final prefs = [
    for (final (i, r) in records.indexed)
      LyricsSourcePrefRow(
        providerId: r.installId,
        enabled: !disabled.contains(r.installId),
        position: i,
      ),
  ];
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      playingLyricsResolutionProvider.overrideWith(() => resolution),
      libraryDatabaseProvider.overrideWithValue(library ? db : null),
      nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new),
      onlineLyricsActionsProvider.overrideWith(
        (ref) => RecordingActions(ref, log, failChoose: failChoose),
      ),
      lyricsSourcesInputProvider.overrideWith(
        (ref) => loadFails
            ? Stream.error(StateError('x'))
            : loaded
            ? Stream.value(LyricsSourcesInput(records, prefs))
            : const Stream.empty(),
      ),
      lyricsTargetProvider.overrideWith(
        (ref) => Stream.value(
          LyricsTarget.fromFields(
            uri: modalUri,
            title: 'Song',
            artist: 'Artist',
            duration: autoSearchable ? const Duration(seconds: 200) : null,
          ),
        ),
      ),
      initialSettingsProvider.overrideWithValue(
        AppSettings(
          onlineLyrics: OnlineLyricsPrefs(
            autoFetch: autoAllowed,
            autoConsent: autoAllowed,
          ),
        ),
      ),
      playingLocalLyricsProvider.overrideWith(
        (ref) async =>
            ownLyrics == null ? null : (uri: modalUri, lyrics: ownLyrics),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final keepOwn = container.listen(playingLocalLyricsProvider, (_, _) {});
  addTearDown(keepOwn.close);
  await container.read(playingLocalLyricsProvider.future);
  await container.read(playerServiceProvider.notifier).openTracks([modalTrack]);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        // A messenger of its own, so a snackbar on it is told apart from one
        // on the app's.
        builder: (context, _) => ScaffoldMessenger(
          child: Scaffold(
            key: openerScaffold,
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.topLeft,
                child: FilledButton(
                  onPressed: () => showLyricsSourceModal(
                    context,
                    messenger: ScaffoldMessenger.maybeOf(context),
                  ),
                  child: const Text('Open modal'),
                ),
              ),
            ),
          ),
        ),
      ),
      for (final path in [
        settingsPlaybackRoute,
        lyricsSourcesRoute,
        lyricsSourcesStoreRoute,
      ])
        GoRoute(path: path, builder: (_, _) => const Scaffold()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.text('Open modal'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  // Streams (the song's lookup fields) deliver after the first frame.
  await tester.pump(const Duration(milliseconds: 50));
  return SourceModalHarness(container, resolution, log, router);
}
