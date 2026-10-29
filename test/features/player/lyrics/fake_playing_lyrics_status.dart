import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

/// A status the test moves by hand, to drive the lyrics view through every
/// state without a library or a network. Override
/// `playingLyricsStatusProvider.overrideWith(() => fake)`.
class FakePlayingLyricsStatus extends PlayingLyricsStatusNotifier {
  FakePlayingLyricsStatus(this._initial);

  final PlayingLyricsStatus? _initial;

  @override
  PlayingLyricsStatus? build() => _initial;

  void emit(PlayingLyricsStatus? next) => state = next;
}

Lyrics fakeSyncedLyrics([String first = 'First words']) => Lyrics(
  lines: [
    LyricLine(Duration.zero, first),
    const LyricLine(Duration(seconds: 5), 'More words'),
  ],
  synced: true,
  source: LyricsSource.sidecar,
);

Lyrics fakePlainLyrics([String first = 'First words']) => Lyrics(
  lines: [LyricLine(Duration.zero, first), LyricLine(Duration.zero, 'More')],
  synced: false,
  source: LyricsSource.sidecar,
);
