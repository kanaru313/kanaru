import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:kanaru/core/fonts/font_catalog_manifest.dart';

String baseName(FileSystemEntity e) =>
    e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);

Uint8List createMockZip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = entry.value.codeUnits;
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

CatalogFontItem testFont(String id, Uint8List zip, {String? sha}) => CatalogFontItem(
      id: id,
      label: 'Test Font',
      family: 'Test Font',
      category: 'sans-serif',
      designer: 'Tester',
      license: 'OFL-1.1',
      filename: '$id.zip',
      sizeBytes: zip.length,
      sha256: sha ?? sha256.convert(zip).toString(),
      previewSvgAsset: '',
    );

/// Minimal sfnt: valid magic bytes and a `name` table with one record.
/// [pad] appends zero bytes so tests can produce different content with the
/// same family name.
Uint8List buildFont(String family, {int nameId = 1, int pad = 0}) {
  void u16(BytesBuilder b, int v) => b.add([v >> 8, v & 0xFF]);
  void u32(BytesBuilder b, int v) => b.add([
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ]);

  final str = <int>[for (final u in family.codeUnits) ...[u >> 8, u & 0xFF]];

  final table = BytesBuilder();
  u16(table, 0); // format
  u16(table, 1); // count
  u16(table, 18); // string offset = 6 + 12
  u16(table, 3); // platform: Windows
  u16(table, 1); // encoding
  u16(table, 0x409); // language
  u16(table, nameId);
  u16(table, str.length);
  u16(table, 0); // string offset inside storage
  table.add(str);
  final tableBytes = table.toBytes();

  final out = BytesBuilder();
  out.add([0x00, 0x01, 0x00, 0x00]); // sfnt version
  u16(out, 1); // numTables
  u16(out, 16); // searchRange
  u16(out, 0); // entrySelector
  u16(out, 0); // rangeShift
  out.add('name'.codeUnits);
  out.add([0, 0, 0, 0]); // checksum
  u32(out, 28); // offset = 12 + 16
  u32(out, tableBytes.length);
  out.add(tableBytes);
  out.add(List<int>.filled(pad, 0));
  return out.toBytes();
}

/// Multi-record sfnt builder supporting arbitrary platforms and name IDs.
Uint8List buildMultiRecordFont({
  List<int> magic = const [0x00, 0x01, 0x00, 0x00],
  required List<({int nameId, int platformId, List<int> bytes})> names,
}) {
  void u16(BytesBuilder b, int v) => b.add([v >> 8, v & 0xFF]);
  void u32(BytesBuilder b, int v) => b.add([
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ]);

  final table = BytesBuilder();
  u16(table, 0); // format
  u16(table, names.length); // count
  u16(table, 6 + names.length * 12); // string offset

  var stringOffset = 0;
  for (final entry in names) {
    u16(table, entry.platformId);
    u16(table, 1); // encoding
    u16(table, 0x0409); // language
    u16(table, entry.nameId);
    u16(table, entry.bytes.length);
    u16(table, stringOffset);
    stringOffset += entry.bytes.length;
  }
  for (final entry in names) {
    table.add(entry.bytes);
  }
  final tableBytes = table.toBytes();

  final out = BytesBuilder();
  out.add(magic);
  u16(out, names.isEmpty ? 0 : 1); // numTables
  u16(out, 16); // searchRange
  u16(out, 0); // entrySelector
  u16(out, 0); // rangeShift
  if (names.isNotEmpty) {
    out.add('name'.codeUnits);
    out.add([0, 0, 0, 0]); // checksum
    u32(out, 28); // offset = 12 + 16
    u32(out, tableBytes.length);
    out.add(tableBytes);
  }
  return out.toBytes();
}

class FakeRegistrar {
  final calls = <({String family, int fileCount})>[];
  bool fail = false;

  Future<void> call(String family, List<Uint8List> fonts) async {
    if (fail) throw StateError('engine rejected font');
    calls.add((family: family, fileCount: fonts.length));
  }
}
