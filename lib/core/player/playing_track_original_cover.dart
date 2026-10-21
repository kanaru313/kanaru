import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'original_cover_reader.dart';
import 'player_service.dart';
import 'playing_track_art.dart';

final _log = Logger('playing_original_cover');

/// The original cover image of the track at [uri].
typedef OriginalCover = ({String uri, Uint8List bytes});

/// Full-size cover of the playing local track, for views that show it larger
/// than its thumbnail; `null` while it is read, when the track has none, is
/// not a local file, or the read failed (logged once per read, never retried:
/// the next track or a new thumbnail reads again). Only watched while such a
/// view is open, so the bytes are not kept otherwise.
///
/// The value carries the uri it was read for: while the next track loads,
/// the previous value may still be there, and a view must not show it.
final playingTrackOriginalCoverProvider =
    FutureProvider.autoDispose<OriginalCover?>((ref) async {
      final uri = ref.watch(
        playerServiceProvider.select((s) => s.queue.current?.uri),
      );
      final path = uri == null ? null : localPathOf(uri);
      if (uri == null || path == null) return null;
      // A scan that replaces the thumbnail may have replaced the cover.
      ref.watch(playingTrackArtProvider);
      final reader = ref.watch(originalCoverReaderProvider);
      try {
        final bytes = await reader.read(path);
        return bytes == null || bytes.isEmpty ? null : (uri: uri, bytes: bytes);
      } catch (error, stackTrace) {
        _log.warning('Reading the original cover failed', error, stackTrace);
        return null;
      }
    }, retry: (_, _) => null);
