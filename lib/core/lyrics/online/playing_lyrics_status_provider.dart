import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playing_lyrics_resolution_provider.dart';
import 'playing_lyrics_status.dart';

export 'online_lyrics_resolution.dart' show notFoundTtl;
export 'auto_lyrics_lookup_provider.dart' show autoLyricsLookupProvider;
export 'playing_lyrics_status.dart';

/// What the playing song's lyrics are, or `null` when nothing plays. The
/// order, by the song's choice, is in `resolveChoice`; a status still being
/// worked out keeps the previous one of the same song (see
/// `playingLyricsResolutionProvider`).
class PlayingLyricsStatusNotifier extends Notifier<PlayingLyricsStatus?> {
  @override
  PlayingLyricsStatus? build() =>
      ref.watch(playingLyricsResolutionProvider.select((r) => r?.status));
}

final playingLyricsStatusProvider =
    NotifierProvider.autoDispose<
      PlayingLyricsStatusNotifier,
      PlayingLyricsStatus?
    >(PlayingLyricsStatusNotifier.new);
