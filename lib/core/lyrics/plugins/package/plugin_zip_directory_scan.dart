import 'dart:math';
import 'dart:typed_data';

import 'plugin_package_limits.dart';
import 'plugin_package_problem.dart';

// Record signatures, little endian.
const _endSignature = 0x06054b50;
const _zip64LocatorSignature = 0x07064b50;
const _centralSignature = 0x02014b50;
const _localSignature = 0x04034b50;

// Caps on the variable parts of a record. A legitimate plugin zip stays far
// below them; they bound what the zip parser may allocate per record.
const _maxNameLength = 1024;
const _maxExtraLength = 1024;
const _maxCommentLength = 1024;

PluginPackageProblem _notZip(String detail) =>
    PluginPackageProblem(PluginPackageProblemKind.notZip, detail: detail);

/// Checks the central directory before the zip parser sees it, and returns
/// the number of entries the end record announces.
///
/// The parser builds an object graph per central record (and reads the local
/// header each one points at), so a few thousand tiny records aimed at one
/// large local header would use far more memory than the file is big. This
/// walk is cheap (it skips records by their lengths) and refuses before that:
///
/// - zip64 and multi-disk archives (a plugin of at most 5 MiB never needs them);
/// - more than the entry cap (`tooManyEntries`), counted on the end record
///   first and again while walking, stopping at the first record over the cap;
/// - a walk that does not end exactly at the announced count and size;
/// - over-long names, extra fields and comments, in central and local headers;
/// - two records sharing one local header (overlapping entries).
///
/// Throws [PluginPackageProblem]: `notZip` unless stated.
int scanPluginZipDirectory(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final end = _findEndRecord(bytes, data);
  if (end < 0) throw _notZip('no end record');
  if (end >= 20 &&
      data.getUint32(end - 20, Endian.little) == _zip64LocatorSignature) {
    throw _notZip('zip64');
  }
  final thisDisk = data.getUint16(end + 4, Endian.little);
  final directoryDisk = data.getUint16(end + 6, Endian.little);
  final diskEntries = data.getUint16(end + 8, Endian.little);
  final total = data.getUint16(end + 10, Endian.little);
  final size = data.getUint32(end + 12, Endian.little);
  final offset = data.getUint32(end + 16, Endian.little);
  if (total == 0xffff || size == 0xffffffff || offset == 0xffffffff) {
    throw _notZip('zip64');
  }
  if (thisDisk != 0 || directoryDisk != 0 || diskEntries != total) {
    throw _notZip('multi-disk');
  }
  if (total > maxPluginZipEntries) {
    throw const PluginPackageProblem(PluginPackageProblemKind.tooManyEntries);
  }
  if (offset + size > end) throw _notZip('directory out of range');

  var position = offset;
  var walked = 0;
  final localOffsets = <int>{};
  while (position < offset + size) {
    if (walked >= maxPluginZipEntries) {
      throw const PluginPackageProblem(PluginPackageProblemKind.tooManyEntries);
    }
    if (position + 46 > offset + size ||
        data.getUint32(position, Endian.little) != _centralSignature) {
      throw _notZip('bad central record');
    }
    final nameLength = data.getUint16(position + 28, Endian.little);
    final extraLength = data.getUint16(position + 30, Endian.little);
    final commentLength = data.getUint16(position + 32, Endian.little);
    if (nameLength > _maxNameLength ||
        extraLength > _maxExtraLength ||
        commentLength > _maxCommentLength) {
      throw _notZip('over-long record field');
    }
    // All-ones marks a value that lives in a zip64 extra field.
    if (data.getUint32(position + 20, Endian.little) == 0xffffffff ||
        data.getUint32(position + 24, Endian.little) == 0xffffffff) {
      throw _notZip('zip64');
    }
    final localOffset = data.getUint32(position + 42, Endian.little);
    if (localOffset == 0xffffffff) throw _notZip('zip64');
    if (!localOffsets.add(localOffset)) throw _notZip('overlapping entries');
    _checkLocalHeader(data, localOffset, offset);
    position += 46 + nameLength + extraLength + commentLength;
    walked++;
  }
  if (position != offset + size || walked != total) {
    throw _notZip('directory does not match the end record');
  }
  return total;
}

/// The local header an entry points at is parsed too: bound its lengths.
void _checkLocalHeader(ByteData data, int at, int directoryStart) {
  if (at + 30 > directoryStart ||
      data.getUint32(at, Endian.little) != _localSignature) {
    throw _notZip('bad local header');
  }
  if (data.getUint16(at + 26, Endian.little) > _maxNameLength ||
      data.getUint16(at + 28, Endian.little) > _maxExtraLength) {
    throw _notZip('over-long record field');
  }
}

/// Offset of the end record, or -1. The zip parser takes the first end
/// signature found scanning back from 22 bytes before the end; so do we, and
/// we also refuse a second signature anywhere in the allowed window (22 bytes
/// plus a comment of at most 64 KiB). The two parsers can then not be led to
/// different records, for example by a fake record inside the real comment.
int _findEndRecord(Uint8List bytes, ByteData data) {
  final lowest = max(0, bytes.length - 22 - 0xffff);
  var found = -1;
  for (var i = bytes.length - 22; i >= lowest; i--) {
    if (data.getUint32(i, Endian.little) != _endSignature) continue;
    if (found >= 0) throw _notZip('more than one end record');
    final commentLength = data.getUint16(i + 20, Endian.little);
    if (i + 22 + commentLength != bytes.length) {
      throw _notZip('end record does not close the file');
    }
    found = i;
  }
  return found;
}
