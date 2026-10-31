import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'embedded_lyrics_reader.dart';
import 'lrc_sidecar_reader.dart';
import 'lyrics.dart';
import 'lyrics_loader.dart';

/// Lyrics found in the tags or the `.lrc` file of the audio file at the
/// path, for any track (not only the playing one). Kept only while a view
/// watches it; read again when the "prefer embedded lyrics" setting changes.
/// `null` when the file has none.
final trackLocalLyricsProvider = FutureProvider.autoDispose
    .family<Lyrics?, String>((ref, path) {
      final preferEmbedded = ref.watch(
        settingsProvider.select((s) => s.playback.preferEmbeddedLyrics),
      );
      return loadLyrics(
        path,
        preferEmbedded: preferEmbedded,
        embedded: ref.watch(embeddedLyricsReaderProvider),
        sidecar: ref.watch(lrcSidecarReaderProvider),
      );
    }, retry: (_, _) => null);
