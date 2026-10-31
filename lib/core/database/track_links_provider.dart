import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_browse_track_links.dart';
import 'library_startup.dart';

/// The artists, album and album artists the song modal links to for the track
/// with the given id; read once when the modal opens. Null without a library
/// or once the track is gone (a rescan removed it).
final trackModalLinksProvider = FutureProvider.autoDispose
    .family<TrackLinks?, int>((ref, id) async {
      final db = ref.watch(libraryDatabaseProvider);
      return db?.trackLinks(id);
    });
