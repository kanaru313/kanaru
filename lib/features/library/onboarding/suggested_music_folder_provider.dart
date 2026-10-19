import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/indexer/xdg_music_directory.dart';

/// The music folder to suggest on first run (`$XDG_MUSIC_DIR`, else
/// `~/Music`), or `null`. Tests override it.
final suggestedMusicFolderProvider = FutureProvider<String?>(
  (ref) => readXdgMusicDirectory(Platform.environment),
);
