import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../settings/app_font.dart';
import 'font_catalog_manifest.dart';
import 'font_storage_service.dart';

final _log = Logger('dynamic_font_loader');

typedef FontBytesRegistrar = Future<void> Function(
  String family,
  List<Uint8List> fonts,
);

Future<void> _registerWithFlutter(String family, List<Uint8List> fonts) async {
  final loader = FontLoader(family);
  for (final bytes in fonts) {
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

class DynamicFontLoader {
  DynamicFontLoader({FontBytesRegistrar? registrar})
      : _registrar = registrar ?? _registerWithFlutter;

  final FontBytesRegistrar _registrar;
  final Set<String> _loaded = {};
  final Map<String, Future<void>> _inFlight = {};
  final Set<String> _licensed = {};

  bool isFamilyLoaded(String family) => _loaded.contains(family);

  /// Registers every file under one family (all weights together).
  /// Concurrent calls for the same family share one load; a failed load can
  /// be retried.
  Future<void> loadFontFamily({
    required String family,
    required List<File> fontFiles,
  }) {
    if (_loaded.contains(family)) return Future.value();
    return _inFlight.putIfAbsent(family, () async {
      try {
        final bytes = <Uint8List>[
          for (final file in fontFiles) await file.readAsBytes(),
        ];
        await _registrar(family, bytes);
        _loaded.add(family);
        _log.info('Loaded family "$family" (${fontFiles.length} files)');
      } finally {
        _inFlight.remove(family);
      }
    });
  }

  /// Makes sure the font behind [fontId] is registered. No-op for built-in
  /// fonts and for fonts that are not installed.
  Future<void> ensureLoaded(String fontId, FontStorageService storage) async {
    final item = catalogFontsManifest.where((c) => c.id == fontId).firstOrNull;
    if (item != null) {
      final files = storage.listFontFilesForFamily(fontId);
      if (files.isNotEmpty) {
        await loadFontFamily(family: item.family, fontFiles: files);
      }
      return;
    }
    if (isCustomFontId(fontId)) {
      final files = storage.listFontFilesForFamily(fontId, isCustom: true);
      if (files.isNotEmpty) {
        await loadFontFamily(family: fontId, fontFiles: files);
      }
    }
  }

  /// Registers every imported font so the fonts page can preview them.
  Future<void> loadAllCustomFonts(FontStorageService storage) async {
    for (final id in storage.listCustomFontIds()) {
      try {
        await ensureLoaded(id, storage);
      } catch (e, st) {
        _log.warning('Failed to load custom font "$id"', e, st);
      }
    }
  }

  void registerFontLicense(String label, String licenseText) {
    if (!_licensed.add(label)) return;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([label], licenseText);
    });
  }

  /// Cheap, does not load any font. Call after the first frame.
  void registerInstalledLicenses(FontStorageService storage) {
    for (final id in storage.listInstalledCatalogFontIds()) {
      final item = catalogFontsManifest.where((c) => c.id == id).firstOrNull;
      if (item == null) continue;
      try {
        final license = storage.readLicenseText(id);
        if (license != null) registerFontLicense(item.label, license);
      } catch (e, st) {
        _log.warning('Failed to register license for "$id"', e, st);
      }
    }
  }
}
