import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_entries.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';

/// A lyrics resolution the test moves by hand, to drive the source button
/// and its menu through every state without a library or a network. Override
/// `playingLyricsResolutionProvider.overrideWith(() => fake)`.
class FakePlayingLyricsResolution extends PlayingLyricsResolutionNotifier {
  FakePlayingLyricsResolution(this._initial);

  final LyricsSourceResolution? _initial;

  @override
  LyricsSourceResolution? build() => _initial;

  void emit(LyricsSourceResolution? next) => state = next;
}

/// A resolution for the tests: by default automatic, nothing stored, no own
/// lyrics.
LyricsSourceResolution fakeResolution(
  PlayingLyricsStatus status, {
  LyricsChoice chosen = LyricsChoice.auto,
  LyricsChoice effective = LyricsChoice.auto,
  LyricsPinEntry? pin,
  bool hasLocal = false,
}) => (
  chosen: chosen,
  effective: effective,
  pin: pin,
  hasLocal: hasLocal,
  status: status,
);

/// A stored pick of the record [remoteId] at [providerId].
LyricsPinEntry fakePin({
  LyricsChoice choice = LyricsChoice.online,
  String providerId = 'fake',
  String remoteId = '7',
  Lyrics? lyrics,
  int? remoteDurationMs = 245000,
}) => LyricsPinEntry(
  pinnedAt: 0,
  choice: choice,
  providerId: providerId,
  remoteId: remoteId,
  lyrics: lyrics,
  remoteDurationMs: remoteDurationMs,
);
