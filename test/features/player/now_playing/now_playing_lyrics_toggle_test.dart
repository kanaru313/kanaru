import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_toggle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../lyrics/lyrics_source_button_harness.dart';

void main() {
  late bool result;

  Future<ButtonHarness> pumpToggle(
    WidgetTester tester,
    LyricsSourceResolution? source, {
    bool library = true,
  }) async {
    final h = await pumpLyricsButton(tester, source, library: library);
    // The button that held the source is gone from the second tree below.
    final keep = h.container.listen(playingLyricsSourceProvider, (_, _) {});
    addTearDown(keep.close);
    // A second tree that runs the toggle on the same container.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => result = quickToggleLyrics(context, ref),
              child: const Text('toggle'),
            ),
          ),
        ),
      ),
    );
    return h;
  }

  testWidgets('turns shown lyrics off', (tester) async {
    final h = await pumpToggle(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics()),
        effective: LyricsChoice.local,
        hasLocal: true,
      ),
    );
    await tester.tap(find.text('toggle'));
    expect(result, isTrue);
    expect(h.log, ['choose off']);
  });

  testWidgets('turns lyrics that are off back on', (tester) async {
    final h = await pumpToggle(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.off),
        chosen: LyricsChoice.off,
        effective: LyricsChoice.off,
      ),
    );
    await tester.tap(find.text('toggle'));
    expect(h.log, ['turnOn']);
  });

  testWidgets('does nothing without the library', (tester) async {
    final h = await pumpToggle(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics())),
      library: false,
    );
    await tester.tap(find.text('toggle'));
    expect(result, isFalse);
    expect(h.log, isEmpty);
  });

  testWidgets('does nothing for a song that is not a local file', (
    tester,
  ) async {
    final h = await pumpToggle(
      tester,
      fakeResolution(LyricsFound('https://example.com/a.mp3', modalLyrics())),
    );
    await tester.tap(find.text('toggle'));
    expect(result, isFalse);
    expect(h.log, isEmpty);
  });

  testWidgets('does nothing when no song plays', (tester) async {
    final h = await pumpToggle(tester, null);
    await tester.tap(find.text('toggle'));
    expect(result, isFalse);
    expect(h.log, isEmpty);
  });
}
