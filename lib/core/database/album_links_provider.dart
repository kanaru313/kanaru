import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_browse_album_links.dart';
import 'library_browse_rows.dart';
import 'library_startup.dart';

/// The artists and folders the album modal links to for an album; read once
/// when the modal opens. Null without a library or once the album is gone (a
/// rescan removed it). A failed read is not retried, so the rows grey out.
final albumModalLinksProvider = FutureProvider.autoDispose
    .family<AlbumLinks?, AlbumKey>((ref, key) async {
      final db = ref.watch(libraryDatabaseProvider);
      return db?.albumLinks(key);
    }, retry: (_, _) => null);
