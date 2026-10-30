import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

/// A manifest that passes every rule; tests copy it and change one thing.
Map<String, dynamic> validManifest() => <String, dynamic>{
  'metadata': <String, dynamic>{
    'apiVersion': 1,
    'type': 'lyrics',
    'name': 'Demo',
    'version': 3,
    'hosts': ['music.example.com'],
    'author': 'someone',
    'description': 'Demo plugin',
  },
  'script': <String, dynamic>{'search': 'search.js', 'lyrics': 'lyrics.js'},
};

/// Smallest valid PNG header: signature + IHDR for [width] x [height].
Uint8List pngHeader(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setAll(0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  bytes.setAll(12, ascii.encode('IHDR'));
  data.setUint32(16, width);
  data.setUint32(20, height);
  return bytes;
}

/// Zip of [entries] (name to String or bytes); a name ending in `/` is a
/// folder. [modes] sets the Unix mode of chosen entries.
Uint8List buildZip(
  Map<String, Object> entries, {
  Map<String, int> modes = const {},
}) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final name = entry.key;
    final value = entry.value;
    final file = name.endsWith('/')
        ? ArchiveFile.directory(name)
        : ArchiveFile.bytes(
            name,
            value is String ? utf8.encode(value) : value as List<int>,
          );
    final mode = modes[name];
    if (mode != null) file.mode = mode;
    archive.add(file);
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// A package with every required entry; [manifest] and [extra] override.
Uint8List validZip({
  Map<String, dynamic>? manifest,
  Map<String, Object> extra = const {},
  String? prefix,
}) {
  final entries = <String, Object>{
    'plugin.json': jsonEncode(manifest ?? validManifest()),
    'src/search.js': 'function execute(q) { return q; }',
    'src/lyrics.js': 'function execute(id) { return id; }',
    ...extra,
  };
  if (prefix == null) return buildZip(entries);
  return buildZip({
    for (final e in entries.entries) '$prefix${e.key}': e.value,
  });
}

/// Fields of an entry's headers that [patchEntry] can rewrite. Offsets are
/// those of the zip format; each value is written in the central record and
/// in the local header of the entry named [name].
Uint8List patchEntry(
  Uint8List zip,
  String name, {
  int? size,
  int? compressedSize,
  int? crc,
  int? method,
  int? flags,
  int? versionMadeBy,
  int? externalAttributes,
}) {
  final out = Uint8List.fromList(zip);
  final data = ByteData.sublistView(out);
  var patched = false;
  for (var i = 0; i + 46 < out.length; i++) {
    if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
    final nameLength = data.getUint16(i + 28, Endian.little);
    final entryName = utf8.decode(out.sublist(i + 46, i + 46 + nameLength));
    if (entryName != name) continue;
    patched = true;
    final local = data.getUint32(i + 42, Endian.little);
    void both(int central, int localAt, int bytes, int value) {
      if (bytes == 2) {
        data.setUint16(i + central, value, Endian.little);
        data.setUint16(local + localAt, value, Endian.little);
      } else {
        data.setUint32(i + central, value, Endian.little);
        data.setUint32(local + localAt, value, Endian.little);
      }
    }

    if (flags != null) {
      both(8, 6, 2, flags);
    }
    if (method != null) {
      both(10, 8, 2, method);
    }
    if (crc != null) {
      both(16, 14, 4, crc);
    }
    if (compressedSize != null) {
      both(20, 18, 4, compressedSize);
    }
    if (size != null) {
      both(24, 22, 4, size);
    }
    if (versionMadeBy != null) {
      data.setUint16(i + 4, versionMadeBy, Endian.little);
    }
    if (externalAttributes != null) {
      data.setUint32(i + 38, externalAttributes, Endian.little);
    }
  }
  if (!patched) throw StateError('no entry $name');
  return out;
}

/// Overwrites fields of the end record (entry counts, directory size and
/// offset) in a copy of [zip].
Uint8List patchEndRecord(
  Uint8List zip, {
  int? entriesOnDisk,
  int? totalEntries,
  int? directorySize,
  int? directoryOffset,
}) {
  final out = Uint8List.fromList(zip);
  final data = ByteData.sublistView(out);
  final end = out.length - 22;
  if (entriesOnDisk != null) {
    data.setUint16(end + 8, entriesOnDisk, Endian.little);
  }
  if (totalEntries != null) {
    data.setUint16(end + 10, totalEntries, Endian.little);
  }
  if (directorySize != null) {
    data.setUint32(end + 12, directorySize, Endian.little);
  }
  if (directoryOffset != null) {
    data.setUint32(end + 16, directoryOffset, Endian.little);
  }
  return out;
}

/// A zip made by hand: one local header with a [localNameLength]-byte name,
/// then [records] central records that all point at it, then an end record
/// announcing [announced] entries (default: [records]).
Uint8List amplifiedZip({
  required int records,
  int localNameLength = 60000,
  int? announced,
}) {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 0xff, v >> 8 & 0xff]);
  void u32(int v) =>
      out.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
  u32(0x04034b50);
  for (final v in [20, 0, 0, 0, 0]) {
    u16(v);
  }
  u32(0);
  u32(0);
  u32(0);
  u16(localNameLength);
  u16(0);
  out.add(List.filled(localNameLength, 0x61));
  final directoryStart = out.length;
  for (var i = 0; i < records; i++) {
    u32(0x02014b50);
    for (final v in [20, 20, 0, 0, 0, 0]) {
      u16(v);
    }
    u32(0);
    u32(0);
    u32(0);
    u16(1);
    u16(0);
    u16(0);
    u16(0);
    u16(0);
    u32(0);
    u32(0);
    out.add([0x61]);
  }
  final directorySize = out.length - directoryStart;
  u32(0x06054b50);
  u16(0);
  u16(0);
  u16(announced ?? records);
  u16(announced ?? records);
  u32(directorySize);
  u32(directoryStart);
  u16(0);
  return out.toBytes();
}

/// A runtime whose syntax check reports [problems] by file name and records
/// what it was asked to check.
class FakePluginRuntime implements PluginRuntime {
  FakePluginRuntime({this.problems = const {}, this.throwOnCheck = false});

  final Map<String, PluginScriptProblem> problems;
  final bool throwOnCheck;
  final checked = <String>[];

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) async {
    checked.add(fileName);
    if (throwOnCheck) throw StateError('library missing');
    return problems[fileName];
  }

  @override
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  }) => throw UnimplementedError('the reader never runs a script');
}

/// Reads [zip] and returns the problem, failing the test when accepted.
Future<PluginPackageProblem> readProblem(
  Uint8List zip, {
  FakePluginRuntime? runtime,
}) async {
  final result = await PluginPackageReader(runtime ?? FakePluginRuntime())
      .read(zip);
  if (result is! PluginPackageRejected) {
    throw StateError('package was accepted');
  }
  return result.problem;
}
