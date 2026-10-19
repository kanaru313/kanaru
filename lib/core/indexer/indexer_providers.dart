import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import 'library_indexer.dart';
import 'library_roots_controller.dart';
import 'indexer_state.dart';
import 'rust_tag_reader.dart';
import 'tag_reader.dart';

export '../database/library_startup.dart' show libraryHasRootsProvider;

/// Reads tags with the Rust `lofty` bridge; tests override it with a fake.
final tagReaderProvider = Provider<TagReader>((ref) => RustTagReader());

final libraryIndexerProvider = NotifierProvider<LibraryIndexer, IndexerState>(
  LibraryIndexer.new,
);

/// The library's source folders, live. Empty when the library is
/// unavailable.
final libraryRootsProvider = StreamProvider<List<LibraryRoot>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchRoots();
});

final libraryRootsControllerProvider = Provider<LibraryRootsController>(
  (ref) => LibraryRootsController(ref),
);
