import 'dart:io';

import '../paths/app_directories.dart';

String _baseName(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');

bool _isFontFile(File f) {
  final lower = f.path.toLowerCase();
  return lower.endsWith('.ttf') || lower.endsWith('.otf');
}

bool _isStagingName(String name) =>
    name.endsWith('.tmp') || name.endsWith('.old');

class FontStorageService {
  FontStorageService({
    Map<String, String>? environment,
    this.baseDirectory,
  }) : _environment = environment ?? Platform.environment;

  static final _validFontIdRegExp = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Validates font IDs against path traversal and malformed inputs.
  /// Only alphanumeric characters, hyphens, and underscores are allowed (max length 128).
  static bool isValidFontId(String? id) =>
      id != null &&
      id.isNotEmpty &&
      id.length <= 128 &&
      _validFontIdRegExp.hasMatch(id);

  static void _checkValidFontId(String id) {
    if (!isValidFontId(id)) {
      throw ArgumentError(
        'Invalid font ID "$id": must match ^[a-zA-Z0-9_-]+\$ and length <= 128',
      );
    }
  }

  final Map<String, String> _environment;
  final Directory? baseDirectory;

  String get _dataRoot =>
      baseDirectory?.path ??
      resolveDataDirectory(_environment) ??
      Directory.systemTemp.path;

  Directory get catalogDirectory => Directory('$_dataRoot/fonts/catalog');

  Directory get customDirectory => Directory('$_dataRoot/fonts/custom');

  Directory fontDirectoryForCatalog(String id) {
    _checkValidFontId(id);
    return Directory('${catalogDirectory.path}/$id');
  }

  Directory stagingDirectoryForCatalog(String id) {
    _checkValidFontId(id);
    return Directory('${catalogDirectory.path}/$id.tmp');
  }

  Directory backupDirectoryForCatalog(String id) {
    _checkValidFontId(id);
    return Directory('${catalogDirectory.path}/$id.old');
  }

  Directory fontDirectoryForCustom(String id) {
    _checkValidFontId(id);
    return Directory('${customDirectory.path}/$id');
  }

  List<File> listFontFilesForFamily(String fontId, {bool isCustom = false}) {
    if (!isValidFontId(fontId)) return const [];
    final dir =
        isCustom ? fontDirectoryForCustom(fontId) : fontDirectoryForCatalog(fontId);
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().where(_isFontFile).toList();
  }

  bool isCatalogFontInstalled(String fontId) {
    if (!isValidFontId(fontId)) return false;
    return listFontFilesForFamily(fontId).isNotEmpty;
  }

  Set<String> listInstalledCatalogFontIds() {
    final dir = catalogDirectory;
    if (!dir.existsSync()) return const {};
    return {
      for (final entity in dir.listSync().whereType<Directory>())
        if (!_isStagingName(_baseName(entity)) &&
            isCatalogFontInstalled(_baseName(entity)))
          _baseName(entity),
    };
  }

  List<String> listCustomFontIds() {
    final dir = customDirectory;
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync().whereType<Directory>())
        if (listFontFilesForFamily(_baseName(entity), isCustom: true).isNotEmpty)
          _baseName(entity),
    ];
  }

  String? readLicenseText(String fontId, {bool isCustom = false}) {
    final dir =
        isCustom ? fontDirectoryForCustom(fontId) : fontDirectoryForCatalog(fontId);
    if (!dir.existsSync()) return null;
    final licenseFiles = dir.listSync().whereType<File>().where((f) {
      final name = _baseName(f).toLowerCase();
      return name == 'ofl.txt' || name == 'license.txt' || name == 'license';
    });
    if (licenseFiles.isEmpty) return null;
    return licenseFiles.first.readAsStringSync();
  }

  Future<void> deleteCatalogFont(String fontId) async {
    for (final dir in [
      fontDirectoryForCatalog(fontId),
      stagingDirectoryForCatalog(fontId),
      backupDirectoryForCatalog(fontId),
    ]) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  }

  /// Repairs leftovers of an interrupted install. Call once at startup.
  /// - `<id>.tmp`: unfinished download, deleted.
  /// - `<id>.old`: previous install parked during a swap. Restored when the
  ///   swap never completed (no `<id>`), deleted otherwise.
  void cleanupStaleStaging() {
    final dir = catalogDirectory;
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync().whereType<Directory>().toList()) {
      final name = _baseName(entity);
      try {
        if (name.endsWith('.tmp')) {
          entity.deleteSync(recursive: true);
        } else if (name.endsWith('.old')) {
          final fontId = name.substring(0, name.length - 4);
          final finalDir = Directory('${dir.path}/$fontId');
          if (isCatalogFontInstalled(fontId)) {
            entity.deleteSync(recursive: true);
          } else {
            if (finalDir.existsSync()) {
              finalDir.deleteSync(recursive: true);
            }
            entity.renameSync(finalDir.path);
          }
        }
      } catch (_) {
        // Best effort; the next launch retries.
      }
    }
  }
}
