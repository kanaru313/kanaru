import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import 'dynamic_font_loader.dart';
import 'font_catalog_manifest.dart';
import 'font_storage_service.dart';

final _log = Logger('font_downloader');

typedef HttpByteFetcher = Future<Uint8List> Function(
  Uri uri, {
  void Function(int received, int total)? onProgress,
});

class FontDownloaderService {
  FontDownloaderService({
    required this.storage,
    required this.fontLoader,
    HttpByteFetcher? fetcher,
  }) : _fetcher = fetcher ?? _defaultFetcher;

  final FontStorageService storage;
  final DynamicFontLoader fontLoader;
  final HttpByteFetcher _fetcher;

  static Future<Uint8List> _defaultFetcher(
    Uri uri, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      final total = response.contentLength > 0 ? response.contentLength : 0;
      var received = 0;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        builder.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<void> downloadAndInstall({
    required CatalogFontItem font,
    void Function(double progress)? onProgress,
  }) async {
    _log.info('Downloading ${font.id} from ${font.downloadUrl}');

    final bytes = await _fetcher(
      Uri.parse(font.downloadUrl),
      onProgress: (received, total) {
        final expected = total > 0 ? total : font.sizeBytes;
        if (expected > 0) {
          onProgress?.call((received / expected).clamp(0.0, 1.0));
        }
      },
    );

    // 1. Integrity
    if (sha256.convert(bytes).toString() != font.sha256.toLowerCase()) {
      throw const FormatException('SHA-256 integrity verification failed');
    }

    // 2. Stage in <id>.tmp, then swap in. The previous install (if any) is
    //    parked in <id>.old so a failure never leaves the user without a font.
    final finalDir = storage.fontDirectoryForCatalog(font.id);
    final tmpDir = storage.stagingDirectoryForCatalog(font.id);
    final oldDir = storage.backupDirectoryForCatalog(font.id);

    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    tmpDir.createSync(recursive: true);

    try {
      _extractInto(tmpDir, bytes);
      _swapIn(tmpDir: tmpDir, finalDir: finalDir, oldDir: oldDir);
    } finally {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    }

    // 3. Register with the engine and the license registry.
    try {
      await fontLoader.loadFontFamily(
        family: font.family,
        fontFiles: storage.listFontFilesForFamily(font.id),
      );
    } catch (_) {
      await storage.deleteCatalogFont(font.id);
      rethrow;
    }
    final license = storage.readLicenseText(font.id);
    if (license != null) fontLoader.registerFontLicense(font.label, license);

    _log.info('Font ${font.id} installed and loaded.');
  }

  /// Extracts only font files and the license, flat, into [tmpDir].
  void _extractInto(Directory tmpDir, Uint8List zipBytes) {
    final written = <String>{};
    var fontCount = 0;

    for (final entry in ZipDecoder().decodeBytes(zipBytes)) {
      if (!entry.isFile) continue;

      final rawName = entry.name.replaceAll('\\', '/');
      final segments = rawName.split('/');
      if (segments.any((s) => s == '..') ||
          rawName.startsWith('/') ||
          RegExp(r'^[A-Za-z]:').hasMatch(rawName)) {
        throw const FormatException('Zip file contains forbidden path elements');
      }

      final filename = segments.last;
      final lower = filename.toLowerCase();
      String? outName;
      if (lower.endsWith('.ttf') || lower.endsWith('.otf')) {
        outName = filename;
        fontCount++;
      } else if (lower == 'ofl.txt' || lower.startsWith('license')) {
        outName = lower.contains('ofl') ? 'OFL.txt' : 'LICENSE.txt';
      }
      if (outName == null) continue; // whitelist: ignore everything else

      if (!written.add(outName.toLowerCase())) {
        throw FormatException('Zip contains duplicate file name: $outName');
      }
      File('${tmpDir.path}/$outName')
          .writeAsBytesSync(entry.content as List<int>);
    }

    if (fontCount == 0) {
      throw const FormatException('Zip contains no font files');
    }
  }

  void _swapIn({
    required Directory tmpDir,
    required Directory finalDir,
    required Directory oldDir,
  }) {
    if (oldDir.existsSync()) oldDir.deleteSync(recursive: true);
    final hadPrevious = finalDir.existsSync();
    if (hadPrevious) finalDir.renameSync(oldDir.path);
    try {
      tmpDir.renameSync(finalDir.path);
    } catch (_) {
      if (hadPrevious) oldDir.renameSync(finalDir.path); // roll back
      rethrow;
    }
    if (oldDir.existsSync()) oldDir.deleteSync(recursive: true);
  }
}
