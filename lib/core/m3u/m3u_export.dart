import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'm3u_write.dart';

/// Writes [entries] as an M3U file at [target] (absolute) and returns how
/// many entries were written and skipped (see `writeM3u`).
///
/// Asking before overwriting is the caller's job. The write is safe: when
/// [target] is a symlink the file it points to is written and the link
/// kept; the text goes to a new temporary file next to it, flushed, then
/// renamed over the target, so a failure never leaves half a playlist.
/// Relative lines are computed from the real folder (symlinks resolved), as
/// a player reading the file resolves them. Throws on I/O failure, after
/// removing the temporary file.
Future<({int written, int skipped})> exportM3uFile(
  String target,
  List<M3uExportEntry> entries,
  M3uPathStyle style,
) async {
  final resolved = await FileSystemEntity.isLink(target)
      ? await File(target).resolveSymbolicLinks()
      : target;
  final slash = resolved.lastIndexOf('/');
  final folder = await Directory(
    slash <= 0 ? '/' : resolved.substring(0, slash),
  ).resolveSymbolicLinks();
  final name = resolved.substring(slash + 1);
  final real = folder == '/' ? '/$name' : '$folder/$name';
  final m3u = writeM3u(entries, style: style, targetDir: folder);

  final temporary = await _createTemporary(real);
  try {
    await temporary.writeAsString(m3u.text, encoding: utf8, flush: true);
    await temporary.rename(real);
  } catch (_) {
    try {
      await temporary.delete();
    } on FileSystemException {
      // Already renamed or gone.
    }
    rethrow;
  }
  return (written: m3u.written, skipped: m3u.skipped);
}

/// A new, empty file next to [path]. `exclusive` never reuses (or follows)
/// a file that is already there; a clash gets a random suffix.
Future<File> _createTemporary(String path) async {
  final random = Random();
  for (var attempt = 0; ; attempt++) {
    final suffix = attempt == 0 ? '$pid' : '$pid.${random.nextInt(1 << 32)}';
    final file = File('$path.$suffix.tmp');
    try {
      return await file.create(exclusive: true);
    } on FileSystemException {
      if (attempt >= 3) rethrow;
    }
  }
}
