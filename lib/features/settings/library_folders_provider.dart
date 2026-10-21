import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_root_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';

/// The library folders, live; empty without a library database.
final libraryRootsProvider = StreamProvider<List<LibraryRoot>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchRoots();
});

/// Whether the folder at a path exists right now. Checked again after every
/// finished scan, so a drive that is plugged back in stops being marked.
final rootFolderPresentProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, path) {
      ref.watch(
        libraryIndexerProvider.select(
          (state) => state is IndexerFinished ? state.at : null,
        ),
      );
      return FileSystemEntity.isDirectory(path);
    });
