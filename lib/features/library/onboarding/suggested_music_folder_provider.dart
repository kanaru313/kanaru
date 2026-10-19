import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/indexer/root_path.dart';
import '../../../core/indexer/xdg_music_directory.dart';

/// The music folder to suggest on first run (`$XDG_MUSIC_DIR`, else
/// `~/Music`) with symlinks resolved, or `null`. Tests override it.
final suggestedMusicFolderProvider = FutureProvider<String?>(
  (ref) => resolveSuggestedMusicFolder(Platform.environment),
);

/// The XDG music folder of [env], canonicalised so that the overlap check
/// against folders picked later (which are canonical) compares like with
/// like. Falls back to the unresolved path when it cannot be resolved.
Future<String?> resolveSuggestedMusicFolder(Map<String, String> env) async {
  final path = await readXdgMusicDirectory(env);
  if (path == null) return null;
  try {
    return (await canonicalizeRoot(path)).path ?? path;
  } on Object {
    return path;
  }
}
