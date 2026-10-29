import 'lyrics_choice.dart';
import 'online_lyrics_entries.dart';
import 'playing_lyrics_status.dart';

/// Everything the lyrics source button and the status are made of, from one
/// resolution of the playing song.
typedef LyricsSourceResolution = ({
  LyricsChoice chosen,
  LyricsChoice effective,
  LyricsPinEntry? pin,
  bool hasLocal,
  PlayingLyricsStatus status,
});
