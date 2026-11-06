import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';
import 'source/modal/lyrics_source_modal_fixtures.dart';
import 'source/modal/lyrics_source_modal_test_harness.dart'
    show FakePlayingLyricsResolution;

export 'source/modal/lyrics_source_modal_fixtures.dart';
export 'source/modal/lyrics_source_modal_test_harness.dart'
    show FakePlayingLyricsResolution, fakeResolution, fakePin;

/// A lyrics button over a scripted resolution, with the actions recorded.
class ButtonHarness {
  ButtonHarness(
    this.container,
    this.resolution,
    this.log,
    this.opener,
    this.events,
  );

  final ProviderContainer container;
  final FakePlayingLyricsResolution resolution;
  final List<String> log;
  final ValueNotifier<bool Function()?> opener;

  /// What the button reported through `onModalChanged`, in order.
  final List<bool> events;
}

Future<ButtonHarness> pumpLyricsButton(
  WidgetTester tester,
  LyricsSourceResolution? initial, {
  List<LyricsPluginRecord> records = const [],
  bool library = true,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final log = <String>[];
  final events = <bool>[];
  final opener = ValueNotifier<bool Function()?>(null);
  final resolution = FakePlayingLyricsResolution(initial);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      playingLyricsResolutionProvider.overrideWith(() => resolution),
      libraryDatabaseProvider.overrideWithValue(library ? db : null),
      onlineLyricsActionsProvider.overrideWith(
        (ref) => RecordingActions(ref, log),
      ),
      lyricsSourcesInputProvider.overrideWith(
        (ref) => Stream.value(LyricsSourcesInput(records, const [])),
      ),
      // The runner reads the song's lookup fields; no database stream here.
      lyricsTargetProvider.overrideWith((ref) => const Stream.empty()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await container.read(playerServiceProvider.notifier).openTracks([modalTrack]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: LyricsSourceButton(
              modalOpener: opener,
              onModalChanged: events.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ButtonHarness(container, resolution, log, opener, events);
}
