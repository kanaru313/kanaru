import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:logging/logging.dart';

import '../settings/app_font.dart';
import 'dynamic_font_loader.dart';
import 'font_header_parser.dart';
import 'font_storage_service.dart';

final _log = Logger('custom_font_service');

const maxCustomFontBytes = 20 * 1024 * 1024;

class CustomFontItem {
  const CustomFontItem({
    required this.id,
    required this.label,
    required this.file,
  });

  final String id;
  final String label;
  final File file;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFontItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          file.path == other.file.path;

  @override
  int get hashCode => Object.hash(id, label, file.path);

  @override
  String toString() => 'CustomFontItem(id: $id, label: $label, path: ${file.path})';
}

typedef PickedFontFile = ({String name, Uint8List bytes});
typedef FontFilePicker = Future<PickedFontFile?> Function();

Future<PickedFontFile?> _pickWithFileSelector() async {
  // GTK filters are case sensitive, so list both cases.
  const group = XTypeGroup(
    label: 'Font Files (*.ttf, *.otf)',
    extensions: <String>['ttf', 'otf', 'TTF', 'OTF'],
  );
  final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
  if (file == null) return null;
  if (await file.length() > maxCustomFontBytes) {
    throw const FormatException('Font file is too large');
  }
  return (name: file.name, bytes: await file.readAsBytes());
}

class CustomFontService {
  CustomFontService({
    required this.storage,
    required this.fontLoader,
    FontFilePicker? picker,
  })  : _picker = picker ?? _pickWithFileSelector;

  final FontStorageService storage;
  final DynamicFontLoader fontLoader;
  final FontFilePicker _picker;

  File get _manifestFile =>
      File('${storage.customDirectory.path}/custom_fonts.json');

  Map<String, String> _readManifest() {
    if (!_manifestFile.existsSync()) return {};
    try {
      final json =
          jsonDecode(_manifestFile.readAsStringSync()) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  void _writeManifest(Map<String, String> manifest) {
    final dir = storage.customDirectory;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final tmp = File('${_manifestFile.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(manifest), flush: true);
    tmp.renameSync(_manifestFile.path); // atomic replace
  }

  List<CustomFontItem> listCustomFonts() {
    final manifest = _readManifest();
    final items = [
      for (final id in storage.listCustomFontIds())
        CustomFontItem(
          id: id,
          label: manifest[id] ?? customFontFallbackLabel(id),
          file: storage.listFontFilesForFamily(id, isCustom: true).first,
        ),
    ];
    items.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return items;
  }

  /// Returns null when the user cancels the picker.
  Future<CustomFontItem?> pickAndImportFont() async {
    final picked = await _picker();
    if (picked == null) return null;
    return importFontBytes(picked.name, picked.bytes);
  }

  Future<CustomFontItem> importFontBytes(
    String fileName,
    Uint8List bytes,
  ) async {
    if (bytes.length > maxCustomFontBytes) {
      throw const FormatException('Font file is too large');
    }
    if (!FontHeaderParser.isValidFontBytes(bytes)) {
      throw const FormatException(
        'Selected file is not a valid TrueType or OpenType font',
      );
    }

    final label =
        FontHeaderParser.extractFontName(bytes) ?? _stripExtension(fileName);
    final id = _idFor(label, bytes);
    final dir = storage.fontDirectoryForCustom(id);

    // Same content already imported: reuse it.
    final existing = storage.listFontFilesForFamily(id, isCustom: true);
    if (existing.isNotEmpty) {
      await fontLoader.loadFontFamily(family: id, fontFiles: existing);
      return CustomFontItem(
        id: id,
        label: _readManifest()[id] ?? label,
        file: existing.first,
      );
    }
    if (dir.existsSync()) await dir.delete(recursive: true); // leftover without fonts

    dir.createSync(recursive: true);
    try {
      final extension =
          fileName.toLowerCase().endsWith('.otf') ? '.otf' : '.ttf';
      final file = File('${dir.path}/$id$extension');
      await file.writeAsBytes(bytes, flush: true);

      // Prove the engine accepts it before keeping it.
      await fontLoader.loadFontFamily(family: id, fontFiles: [file]);

      final manifest = _readManifest()..[id] = label;
      _writeManifest(manifest);
      _log.info('Imported custom font "$label" as "$id"');
      return CustomFontItem(id: id, label: label, file: file);
    } catch (_) {
      if (dir.existsSync()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> deleteCustomFont(String fontId) async {
    final dir = storage.fontDirectoryForCustom(fontId);
    if (dir.existsSync()) await dir.delete(recursive: true);
    final manifest = _readManifest()..remove(fontId);
    _writeManifest(manifest);
    _log.info('Deleted custom font: $fontId');
  }

  static String _stripExtension(String name) =>
      name.replaceAll(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '');

  static String _idFor(String label, Uint8List bytes) {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final base =
        slug.isEmpty ? 'font' : (slug.length > 24 ? slug.substring(0, 24) : slug);
    final hash = sha256.convert(bytes).toString().substring(0, 8);
    return '$customFontIdPrefix${base}_$hash';
  }
}
