import 'dart:convert';
import 'dart:io';

import '../../indexer/root_path.dart';
import '../../m3u/m3u_read.dart';
import '../lrc_sidecar_reader.dart';
import '../lyrics_text_decoder.dart';
import 'lyrics_provider.dart';
import 'online_lyrics_entries.dart';

final _trailingNewlines = RegExp(r'\n+$');

/// Name prefix of the private folder a `.lrc` is written in.
const lrcTempFolderPrefix = '.kanaru-lrc-';

/// A temp folder older than this is a leftover of a crashed write.
const lrcTempFolderMaxAge = Duration(minutes: 10);

/// What goes into a `.lrc` file: [text] (LF line ends, one final newline)
/// and its UTF-8 [bytes].
typedef EncodedLrc = ({String text, List<int> bytes});

/// The file content for [body], or `null` for nothing to write: an
/// instrumental record, no text that parses (the same rule as the lyrics on
/// screen) or more text than a `.lrc` file may hold.
EncodedLrc? encodeLrc(LyricsBody body) {
  if (body.instrumental) return null;
  final stored = storedLyricsText(synced: body.syncedLrc, plain: body.plain);
  if (stored == null) return null;
  final normalized = stored
      .replaceAll('\r\n', '\n')
      .replaceFirst(_trailingNewlines, '');
  if (normalized.isEmpty) return null;
  final text = '$normalized\n';
  final bytes = utf8.encode(text);
  return bytes.length > lrcMaxBytes ? null : (text: text, bytes: bytes);
}

/// What an existing `.lrc` candidate is. Links are not followed.
typedef ExistingCandidate = ({String path, bool replaceable});

/// The candidates that exist, of any type (a dangling link included), in
/// order. Only a regular file or a link can be moved to the trash.
Future<List<ExistingCandidate>> existingCandidates(List<String> paths) async {
  final found = <ExistingCandidate>[];
  for (final path in paths) {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    found.add((
      path: path,
      replaceable:
          type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link,
    ));
  }
  return found;
}

/// The names (not paths) of the `.lrc` / `.LRC` entries that exist next to
/// [audioPath], in order. A link counts; nothing is followed.
Future<List<String>> existingLrcSidecars(String audioPath) async {
  final found = await existingCandidates(lrcCandidates(audioPath));
  return [for (final e in found) e.path.split('/').last];
}

/// The file at [path] holds exactly [text]. A FIFO, a folder, an oversized or
/// unreadable file does not (nothing is opened that could block).
Future<bool> holdsLrcText(String path, String text) async {
  try {
    final bytes = await readM3uBytes(path, maxBytes: lrcMaxBytes);
    return decodeLyricsBytes(bytes) == text;
  } on M3uReadException {
    return false;
  }
}

/// The song is a regular file, and both it and the folder the `.lrc` goes
/// into resolve to a place inside a root and outside every exclusion.
Future<bool> insideLibrary(
  String audioPath, {
  required Future<List<String>> Function() libraryRoots,
  required Future<List<String>> Function() excludedFolders,
}) async {
  if (!audioPath.startsWith('/') || audioPath.lastIndexOf('/') < 0) {
    return false;
  }
  final String file;
  final String dir;
  try {
    file = await File(audioPath).resolveSymbolicLinks();
    dir = await Directory(audioPath.substring(0, audioPath.lastIndexOf('/')))
        .resolveSymbolicLinks();
    if ((await FileStat.stat(file)).type != FileSystemEntityType.file) {
      return false;
    }
  } on FileSystemException {
    return false;
  }
  final roots = await libraryRoots();
  final excluded = await excludedFolders();
  bool allowed(String path) =>
      roots.any((root) => isSameOrInside(root, path)) &&
      !excluded.any((folder) => isSameOrInside(folder, path));
  return allowed(file) && allowed(dir);
}

/// Removes the leftover temp folders in [dir]: real folders named
/// [lrcTempFolderPrefix]* last modified more than [lrcTempFolderMaxAge]
/// before [now]. Best effort: errors are ignored and links are never
/// followed.
Future<void> sweepStaleTempFolders(String dir, DateTime now) async {
  try {
    await for (final entity in Directory(dir).list(followLinks: false)) {
      if (entity is! Directory) continue;
      if (!entity.path.split('/').last.startsWith(lrcTempFolderPrefix)) {
        continue;
      }
      try {
        final age = now.difference((await entity.stat()).modified);
        if (age > lrcTempFolderMaxAge) await entity.delete(recursive: true);
      } on FileSystemException {
        // Gone already, or not ours to remove.
      }
    }
  } on FileSystemException {
    // An unreadable folder: the write will fail with its own error.
  }
}

/// Removes the temp folder of a write; already gone is fine.
Future<void> removeTempFolder(Directory? temp) async {
  if (temp == null) return;
  try {
    await temp.delete(recursive: true);
  } on FileSystemException {
    // Already gone, or not ours to remove any more.
  }
}
