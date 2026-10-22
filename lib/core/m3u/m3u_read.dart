import 'dart:io';
import 'dart:typed_data';

/// Largest M3U file read: far above any real playlist (50 000 lines of
/// 300 bytes is 15 MB), small enough to hold in memory.
const m3uMaxBytes = 16 * 1024 * 1024;

/// Why an M3U file could not be read.
enum M3uReadError {
  /// Not a regular file: a folder, a FIFO, a device, or missing.
  notAFile,

  /// Larger than [m3uMaxBytes].
  tooLarge,

  /// Any I/O failure (permissions, a vanished mount).
  unreadable,
}

/// Thrown by `importM3uFile` when the file cannot be read.
class M3uReadException implements Exception {
  const M3uReadException(this.error);

  final M3uReadError error;

  @override
  String toString() => 'M3uReadException(${error.name})';
}

/// The bytes of the M3U file at [path], at most [maxBytes] of them.
///
/// The type is checked before opening, so a FIFO is never opened (opening
/// one blocks). The file is then opened once and read through that handle
/// with a cap, so a file swapped or grown after the check still cannot make
/// the read unbounded.
Future<Uint8List> readM3uBytes(
  String path, {
  int maxBytes = m3uMaxBytes,
}) async {
  final FileSystemEntityType type;
  try {
    type = await FileSystemEntity.type(path);
  } on FileSystemException {
    throw const M3uReadException(M3uReadError.unreadable);
  }
  if (type != FileSystemEntityType.file) {
    throw const M3uReadException(M3uReadError.notAFile);
  }
  RandomAccessFile? handle;
  try {
    handle = await File(path).open();
    final length = await handle.length();
    if (length > maxBytes) throw const M3uReadException(M3uReadError.tooLarge);
    // One byte more than the length tells a file that grew since; a read may
    // return fewer bytes than asked (network and FUSE mounts), so loop.
    final buffer = Uint8List(length + 1);
    var filled = 0;
    while (filled < buffer.length) {
      final read = await handle.readInto(buffer, filled);
      if (read == 0) break;
      filled += read;
    }
    if (filled > length) {
      // Grown after the length was read: read on, still capped.
      final rest = await handle.read(maxBytes + 1 - filled);
      if (filled + rest.length > maxBytes) {
        throw const M3uReadException(M3uReadError.tooLarge);
      }
      return Uint8List.fromList([...buffer, ...rest]);
    }
    return Uint8List.sublistView(buffer, 0, filled);
  } on FileSystemException {
    throw const M3uReadException(M3uReadError.unreadable);
  } finally {
    await handle?.close();
  }
}
