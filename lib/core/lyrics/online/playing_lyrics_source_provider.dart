import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playing_lyrics_resolution_provider.dart';

export 'playing_lyrics_resolution_provider.dart' show LyricsSourceResolution;

/// What the lyrics source pill shows for the playing song, or `null` when
/// nothing plays: the stored choice (`chosen`), the choice actually in effect
/// (`effective`; differs when the choice cannot be honoured), the stored pin
/// with its pick, whether the song has its own lyrics, and the status. It is
/// the same resolution as the status, so the rule is written once and no
/// extra database stream is opened per song.
final playingLyricsSourceProvider =
    Provider.autoDispose<LyricsSourceResolution?>(
      (ref) => ref.watch(playingLyricsResolutionProvider),
    );
