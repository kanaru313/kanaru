import 'dart:io';

import '../indexer/audio_file_types.dart';

/// `scheme://` at the start of a string (RFC 3986 scheme characters).
final _schemeWithAuthority = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*://');

/// The canonical path of a local audio file named by [input], or `null`.
///
/// This is the one check every path from outside the library must go
/// through before it reaches the player or the database (files opened from
/// the command line, M3U lines, restored sessions). The player hands strings to
/// mpv as they are, and mpv opens `http://`, `edl://`, `av://lavfi:` and other
/// protocols, so only a plain local file may pass.
///
/// [input] may be:
/// - an absolute path;
/// - a `file:` URI (`file:///a/b.flac`, `file://localhost/a/b.flac`), which
///   is percent-decoded;
/// - a relative path, resolved against [baseDirectory] (for example the
///   folder of an M3U file). Without a [baseDirectory], or with one that is
///   not absolute, a relative path gives `null`.
///
/// Any other `scheme://` gives `null`. A string like `Artist: Song.mp3` has
/// no `//` after the colon and is read as a relative file name; the result is
/// still an absolute path to an existing file, never a protocol.
///
/// The result follows invariant 1 of `lib/core/database/user_data_tables.dart`
/// (the spelling the indexer stores in `tracks.path`): the parent folder's
/// symlinks are resolved and `.`/`..` removed, while the file name is kept as
/// written, even when the file itself is a symlink. It is returned only when
/// it names an existing regular file (a symlink to one counts) whose
/// extension is in `audioExtensions`; folders, missing files, other file
/// types and names containing a NUL byte give `null`.
///
/// Limits: the name is not looked up on disk, so on a case-insensitive
/// mount (vfat, exFAT, casefold folders) a name spelled with other case
/// passes as written and will not match `tracks.path`. A local file is
/// accepted by name and extension only: what mpv does with its content
/// (for example an EDL or playlist inside) is the player's setting.
Future<String?> localAudioPath(String input, {String? baseDirectory}) async {
  final path = _absolutePath(input, baseDirectory);
  if (path == null || path.contains('\u0000')) return null;

  final slash = path.lastIndexOf('/');
  final name = path.substring(slash + 1);
  if (name.isEmpty || name == '.' || name == '..' || !isAudioFile(name)) {
    return null;
  }
  final parent = slash == 0 ? '/' : path.substring(0, slash);

  final String resolvedParent;
  try {
    resolvedParent = await Directory(parent).resolveSymbolicLinks();
  } on FileSystemException {
    return null;
  }
  final canonical = resolvedParent == '/' ? '/$name' : '$resolvedParent/$name';
  final type = await FileSystemEntity.type(canonical);
  return type == FileSystemEntityType.file ? canonical : null;
}

/// [input] as an absolute path, not yet canonical; `null` when it is a
/// non-file URI, a malformed `file:` URI or a relative path with no usable
/// [baseDirectory].
String? _absolutePath(String input, String? baseDirectory) {
  if (input.isEmpty) return null;
  if (_schemeWithAuthority.hasMatch(input) ||
      input.toLowerCase().startsWith('file:')) {
    return _filePathFromUri(input);
  }
  if (input.startsWith('/')) return input;
  if (baseDirectory == null || !baseDirectory.startsWith('/')) return null;
  return baseDirectory.endsWith('/')
      ? '$baseDirectory$input'
      : '$baseDirectory/$input';
}

/// The decoded path of a `file:` URI with no host (or `localhost`), no query
/// and no fragment; `null` for anything else.
String? _filePathFromUri(String input) {
  final Uri uri;
  try {
    uri = Uri.parse(input);
  } on FormatException {
    return null;
  }
  if (uri.scheme.toLowerCase() != 'file' ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      (uri.host.isNotEmpty && uri.host.toLowerCase() != 'localhost')) {
    return null;
  }
  try {
    // Percent-decodes as UTF-8; invalid sequences throw.
    final path = Uri.decodeComponent(uri.path);
    return path.startsWith('/') ? path : null;
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}
