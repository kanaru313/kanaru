import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/settings_routes.dart';

import 'lyrics_source_modal_test_harness.dart';

void main() {
  final title = find.text('Lyrics for this song');
  final shown = fakeResolution(
    LyricsFound(modalUri, modalLyrics()),
    effective: LyricsChoice.local,
    hasLocal: true,
  );

  testWidgets('shows the title only, with no song info', (tester) async {
    await pumpSourceModal(tester, shown);
    expect(title, findsOneWidget);
    expect(find.text('Song'), findsNothing);
    expect(find.text('Artist'), findsNothing);
  });

  testWidgets('settings button leaves Now Playing for the lyrics settings', (
    tester,
  ) async {
    final h = await pumpSourceModal(tester, shown);
    await tester.tap(find.byTooltip('Lyrics settings'));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(h.location, settingsFocusLocation(SettingsAnchor.playbackLyrics));
  });

  testWidgets('close button closes the modal', (tester) async {
    await pumpSourceModal(tester, shown);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
  });

  testWidgets('another song closes the whole stack', (tester) async {
    final h = await pumpSourceModal(tester, shown);
    h.resolution.emit(
      fakeResolution(LyricsFound(otherTrack.uri, modalLyrics())),
    );
    await tester.pumpAndSettle();
    expect(title, findsNothing);
  });

  testWidgets('nothing playing closes the stack', (tester) async {
    final h = await pumpSourceModal(tester, shown);
    h.resolution.emit(null);
    await tester.pumpAndSettle();
    expect(title, findsNothing);
  });

  testWidgets('loading gate: neutral line, disabled rows, no counts or Find', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(LyricsNone(modalUri, LyricsNoneReason.noLyrics)),
      loaded: false,
      records: [modalRecord('plugin-a', 'Alpha')],
    );
    expect(find.text('Checking lyrics sources…'), findsOneWidget);
    expect(find.text('Find lyrics online…'), findsNothing);
    expect(find.text('Add an online lyrics source'), findsNothing);
  });

  testWidgets('a failed source list gets the same neutral state', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(LyricsNone(modalUri, LyricsNoneReason.noLyrics)),
      loadFails: true,
    );
    expect(find.text('Checking lyrics sources…'), findsOneWidget);
    expect(find.text('Find lyrics online…'), findsNothing);
  });
}
