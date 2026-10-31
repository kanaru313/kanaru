import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/track_lyrics_preview_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/track_details/track_details.dart';
import 'package:kanaru/core/track_details/track_details_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/song_modal/open_song_modal.dart';
import 'package:material_ui/material_ui.dart';

import '../song_modal_test_support.dart' hide openSongModal;

const lyricsTestPath = '/m/1.flac';
const lyricsTestSong = TrackListItem(id: 1, path: lyricsTestPath, title: 'one');

final lyricsTestDetails = TrackDetails(
  id: 1,
  title: 'One',
  localPath: lyricsTestPath,
  artist: 'Somebody',
  sizeBytes: 1000,
  modifiedAtMs: 0,
  addedAtMs: 0,
  playCount: 0,
);

/// Lyrics of [texts], one per second when [synced].
Lyrics lyricsOf(
  List<String> texts, {
  bool synced = false,
  LyricsSource source = LyricsSource.sidecar,
}) => Lyrics(
  lines: [
    for (var i = 0; i < texts.length; i++)
      LyricLine(synced ? Duration(seconds: i + 1) : Duration.zero, texts[i]),
  ],
  synced: synced,
  source: source,
);

/// Opens the song modal on the Song info page with [preview] as the lyrics.
Future<ProviderContainer> openLyricsInfo(
  WidgetTester tester,
  AsyncValue<TrackLyricsPreview?> preview, {
  Size size = const Size(360, 900),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      trackDetailsProvider.overrideWith(
        (ref, id) => Stream.value(lyricsTestDetails),
      ),
      trackLyricsPreviewProvider.overrideWith((ref, path) => preview),
      lyricsSourceNamesProvider.overrideWithValue(const {
        'lrclib': LyricsSourceName(displayName: 'LRCLIB'),
      }),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => openSongModal(
                context,
                ref,
                song: lyricsTestSong,
                onQueueAction: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleSongModal(tester);
  await openSongInfoPage(tester);
  return container;
}

/// Turns the eye of the Song info page on or off in the stored settings.
void setShowUnknown(ProviderContainer container, {required bool on}) {
  final notifier = container.read(settingsProvider.notifier);
  notifier.setDisplay(
    container.read(settingsProvider).display.copyWith(songInfoShowUnknown: on),
  );
}
