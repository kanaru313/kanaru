import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/local_path_of.dart';
import '../player/player_service.dart';
import '../settings/settings_provider.dart';
import 'embedded_lyrics_reader.dart';
import 'lrc_sidecar_reader.dart';
import 'lyrics.dart';
import 'lyrics_loader.dart';

/// The lyrics of the track at [uri].
typedef PlayingLyrics = ({String uri, Lyrics lyrics});

/// Lyrics of the playing local track found in its tags or `.lrc` file, read
/// when it plays and kept only while a view watches it (nothing is stored).
/// `null` while nothing plays, for a track that is not a local file, or when
/// it has no lyrics. Read again when the track or the "prefer embedded
/// lyrics" setting changes; never retried otherwise.
///
/// The value carries the uri it was read for: while the next track's
/// lyrics load, the previous value is still there, and a consumer must not
/// show it as the new track's.
final playingLocalLyricsProvider = FutureProvider.autoDispose<PlayingLyrics?>((
  ref,
) async {
  final uri = ref.watch(
    playerServiceProvider.select((s) => s.queue.current?.uri),
  );
  final path = uri == null ? null : localPathOf(uri);
  if (uri == null || path == null) return null;
  final preferEmbedded = ref.watch(
    settingsProvider.select((s) => s.playback.preferEmbeddedLyrics),
  );
  final lyrics = await loadLyrics(
    path,
    preferEmbedded: preferEmbedded,
    embedded: ref.watch(embeddedLyricsReaderProvider),
    sidecar: ref.watch(lrcSidecarReaderProvider),
  );
  return lyrics == null ? null : (uri: uri, lyrics: lyrics);
}, retry: (_, _) => null);
