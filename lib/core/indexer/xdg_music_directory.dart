import 'dart:io';

import 'package:logging/logging.dart';

import '../paths/app_directories.dart';
import 'root_path.dart';

final _log = Logger('library');

final _musicLine = RegExp(r'^XDG_MUSIC_DIR\s*=\s*"([^"]*)"\s*$');

/// The user's music folder to suggest on first run, or `null`.
///
/// Reads `XDG_MUSIC_DIR` from [userDirsContent] (the text of
/// `user-dirs.dirs`). Only `"$HOME/…"` and absolute values are accepted, and
/// the result is normalised (no `.`/empty segments, no trailing slash). The
/// value is dropped when it is empty, relative, contains `..`, is `$HOME`
/// itself (how xdg-user-dirs marks a folder as disabled, also as `"$HOME/"`),
/// is `/` or a parent of `$HOME`, or is not an existing folder. Then
/// `$HOME/Music` is tried. [isDirectory] is the existence check, injectable
/// for tests.
String? xdgMusicDirectory(
  Map<String, String> env,
  String? userDirsContent, {
  bool Function(String path)? isDirectory,
}) {
  final exists = isDirectory ?? (path) => Directory(path).existsSync();
  final rawHome = env['HOME'];
  if (rawHome == null || !rawHome.startsWith('/')) return null;
  final home = _normalize(rawHome);
  if (home == null || home == '/') return null;

  bool usable(String? path) =>
      path != null &&
      path != '/' &&
      path != home &&
      !isSameOrInside(path, home) &&
      exists(path);

  final configured = _fromUserDirs(userDirsContent, home);
  if (usable(configured)) return configured;
  final fallback = '$home/Music';
  return usable(fallback) ? fallback : null;
}

/// Reads `user-dirs.dirs` from `$XDG_CONFIG_HOME` (only when absolute, else
/// `~/.config`) and returns [xdgMusicDirectory]. A missing or unreadable file
/// just means no configured value.
Future<String?> readXdgMusicDirectory(Map<String, String> env) async {
  String? content;
  // resolveConfigDirectory appends `/kanaru`; the user-dirs file is one level up.
  final appConfig = resolveConfigDirectory(env);
  if (appConfig != null) {
    final base = appConfig.substring(0, appConfig.length - '/kanaru'.length);
    try {
      content = await File('$base/user-dirs.dirs').readAsString();
    } on FileSystemException catch (error) {
      _log.fine('No readable user-dirs.dirs: $error');
    } on FormatException catch (error) {
      _log.fine('user-dirs.dirs is not valid text: $error');
    }
  }
  return xdgMusicDirectory(env, content);
}

/// The normalised `XDG_MUSIC_DIR` value, or `null` when missing or invalid.
String? _fromUserDirs(String? content, String home) {
  if (content == null) return null;
  String? value;
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('#')) continue;
    final match = _musicLine.firstMatch(trimmed);
    if (match != null) value = match.group(1); // the last assignment wins
  }
  if (value == null || value.isEmpty) return null;
  if (value == r'$HOME' || value.startsWith(r'$HOME/')) {
    value = home + value.substring(r'$HOME'.length);
  }
  return value.startsWith('/') ? _normalize(value) : null;
}

/// [path] without empty and `.` segments and trailing slash; `null` when it
/// has a `..` segment.
String? _normalize(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '..') return null;
    if (segment.isEmpty || segment == '.') continue;
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}
