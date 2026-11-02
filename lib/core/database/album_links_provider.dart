import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_browse_album_links.dart';
import 'library_browse_rows.dart';
import 'library_keys_provider.dart';
import 'library_startup.dart';

/// The artists and folders the album modal links to for an album; read once
/// when the modal opens. Null without a library or once the album is gone (a
/// rescan removed it). Waits (stays pending) while the library keys are being
/// rewritten, then reads afresh once they are ready: a regroup can change the
/// album's key, so the read may then become null. A failed read is not
/// retried, so the rows grey out.
final albumModalLinksProvider = FutureProvider.autoDispose
    .family<AlbumLinks?, AlbumKey>((ref, key) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Future.value(null);
      // Keys are rewritten while not ready: wait, then read afresh.
      if (!ref.watch(keysReadyProvider)) return Completer<AlbumLinks?>().future;
      return db.albumLinks(key);
    }, retry: (_, _) => null);
