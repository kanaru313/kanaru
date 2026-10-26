import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';

void main() {
  const split = NowPlayingViewMode.split;
  const lyricsOnly = NowPlayingViewMode.lyricsOnly;
  const coverOnly = NowPlayingViewMode.coverOnly;
  const unknown = NowPlayingLyricsState.unknown;
  const available = NowPlayingLyricsState.available;
  const none = NowPlayingLyricsState.none;

  group('effectiveViewMode', () {
    const table = {
      (split, unknown): split,
      (split, available): split,
      (split, none): split,
      (lyricsOnly, unknown): lyricsOnly,
      (lyricsOnly, available): lyricsOnly,
      (lyricsOnly, none): coverOnly,
      (coverOnly, unknown): coverOnly,
      (coverOnly, available): coverOnly,
      (coverOnly, none): coverOnly,
    };
    for (final MapEntry(key: (chosen, lyrics), value: expected)
        in table.entries) {
      test('$chosen with lyrics $lyrics shows $expected', () {
        expect(effectiveViewMode(chosen, lyrics), expected);
      });
    }
  });

  group('nextViewMode', () {
    const table = {
      (split, unknown): lyricsOnly,
      (split, available): lyricsOnly,
      (split, none): coverOnly,
      (lyricsOnly, unknown): coverOnly,
      (lyricsOnly, available): coverOnly,
      (lyricsOnly, none): coverOnly,
      (coverOnly, unknown): split,
      (coverOnly, available): split,
      (coverOnly, none): split,
    };
    for (final MapEntry(key: (shown, lyrics), value: expected)
        in table.entries) {
      test('after $shown with lyrics $lyrics comes $expected', () {
        expect(nextViewMode(shown, lyrics), expected);
      });
    }
  });
}
