import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import 'library_indexer.dart';
import 'library_roots_controller.dart';
import 'indexer_state.dart';
import 'root_scan_result.dart';
import 'rust_tag_reader.dart';
import 'tag_reader.dart';
import 'walk_audio_files.dart';

export '../database/library_startup.dart' show libraryHasRootsProvider;
export 'cover_pass_state.dart';

/// Reads tags with the Rust `lofty` bridge; tests override it with a fake.
/// Writes cover thumbnails into [coverCacheDirectoryProvider] when it is set.
final tagReaderProvider = Provider<TagReader>(
  (ref) =>
      RustTagReader(coverDirectory: ref.watch(coverCacheDirectoryProvider)),
);

/// How long a root may take to walk or read; tests override it with short
/// durations.
final scanTimeoutsProvider = Provider<ScanTimeouts>(
  (ref) => const ScanTimeouts(),
);

/// Lists the audio files under a root; tests override it with a fake.
final rootWalkerProvider = Provider<Future<WalkResult> Function(String root)>(
  (ref) => walkAudioFilesInIsolate,
);

final libraryIndexerProvider = NotifierProvider<LibraryIndexer, IndexerState>(
  LibraryIndexer.new,
);

final libraryRootsControllerProvider = Provider<LibraryRootsController>(
  (ref) => LibraryRootsController(ref),
);
