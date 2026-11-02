import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_browse_track_links.dart';
import 'library_keys_provider.dart';
import 'library_startup.dart';

/// The artists, album and album artists the song modal links to for the track
/// with the given id; read once when the modal opens. Null without a library
/// or once the track is gone (a rescan removed it). Waits (stays pending)
/// while the library keys are being rewritten, then reads afresh once they
/// are ready: the artist and album keys of the links come from that rewrite.
final trackModalLinksProvider = FutureProvider.autoDispose
    .family<TrackLinks?, int>((ref, id) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Future.value(null);
      // Keys are rewritten while not ready: wait, then read afresh.
      if (!ref.watch(keysReadyProvider)) return Completer<TrackLinks?>().future;
      return db.trackLinks(id);
    });
