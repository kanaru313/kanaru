import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_catalog_manifest.dart';
import 'package:kanaru/core/fonts/font_downloader_service.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

Uint8List _createZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late DynamicFontLoader loader;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_downloader_test_');
    storage = FontStorageService(baseDirectory: tempDir);
    loader = DynamicFontLoader(registrar: (family, fonts) async {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CatalogFontItem makeItem({
    required String id,
    required String family,
    required String filename,
    required int sizeBytes,
    required String sha256,
  }) {
    return CatalogFontItem(
      id: id,
      label: family,
      family: family,
      category: 'sans-serif',
      designer: 'Test Designer',
      license: 'OFL-1.1',
      filename: filename,
      sizeBytes: sizeBytes,
      sha256: sha256,
      previewSvgAsset: 'assets/font_previews/$id.svg',
    );
  }

  group('FontDownloaderService', () {
    test('successfully downloads, extracts, installs, and loads font', () async {
      final zipBytes = _createZip({
        'TestFont-Regular.ttf': [1, 2, 3, 4],
        'TestFont-Bold.otf': [5, 6, 7, 8],
        'OFL.txt': 'OFL License 1.1'.codeUnits,
        'random_ignored.txt': 'ignored'.codeUnits,
      });
      final digest = sha256.convert(zipBytes).toString();

      final fontItem = makeItem(
        id: 'test-font',
        family: 'Test Font',
        filename: 'test-font.zip',
        sizeBytes: zipBytes.length,
        sha256: digest,
      );

      final progressValues = <double>[];
      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async {
          onProgress?.call(zipBytes.length, zipBytes.length);
          return zipBytes;
        },
      );

      await downloader.downloadAndInstall(
        font: fontItem,
        onProgress: (p) => progressValues.add(p),
      );

      expect(progressValues, contains(1.0));
      expect(storage.isCatalogFontInstalled('test-font'), isTrue);

      final fontFiles = storage.listFontFilesForFamily('test-font');
      final filenames = fontFiles.map((f) => f.uri.pathSegments.last).toSet();
      expect(filenames, {'TestFont-Regular.ttf', 'TestFont-Bold.otf'});

      expect(storage.readLicenseText('test-font'), 'OFL License 1.1');
      expect(loader.isFamilyLoaded('Test Font'), isTrue);
    });

    test('rejects download when SHA-256 does not match', () async {
      final zipBytes = _createZip({
        'TestFont.ttf': [1, 2],
        'OFL.txt': 'license'.codeUnits,
      });

      final fontItem = makeItem(
        id: 'bad-sha-font',
        family: 'Bad SHA Font',
        filename: 'bad-sha.zip',
        sizeBytes: zipBytes.length,
        sha256: '0000000000000000000000000000000000000000000000000000000000000000',
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => zipBytes,
      );

      expect(
        () => downloader.downloadAndInstall(font: fontItem),
        throwsFormatException,
      );
      expect(storage.isCatalogFontInstalled('bad-sha-font'), isFalse);
    });

    test('rejects path traversal in zip', () async {
      final zipBytes = _createZip({
        '../evil.ttf': [1, 2],
        'OFL.txt': 'license'.codeUnits,
      });
      final digest = sha256.convert(zipBytes).toString();

      final fontItem = makeItem(
        id: 'evil-font',
        family: 'Evil Font',
        filename: 'evil.zip',
        sizeBytes: zipBytes.length,
        sha256: digest,
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => zipBytes,
      );

      expect(
        () => downloader.downloadAndInstall(font: fontItem),
        throwsFormatException,
      );
      expect(storage.isCatalogFontInstalled('evil-font'), isFalse);
    });

    test('rejects zip containing no font files', () async {
      final zipBytes = _createZip({
        'OFL.txt': 'license'.codeUnits,
        'readme.md': 'readme'.codeUnits,
      });
      final digest = sha256.convert(zipBytes).toString();

      final fontItem = makeItem(
        id: 'no-font',
        family: 'No Font',
        filename: 'nofont.zip',
        sizeBytes: zipBytes.length,
        sha256: digest,
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => zipBytes,
      );

      expect(
        () => downloader.downloadAndInstall(font: fontItem),
        throwsFormatException,
      );
      expect(storage.isCatalogFontInstalled('no-font'), isFalse);
    });

    test('rejects zip containing duplicate output names', () async {
      final zipBytes = _createZip({
        'folder1/Font.ttf': [1],
        'folder2/Font.ttf': [2],
        'OFL.txt': 'license'.codeUnits,
      });
      final digest = sha256.convert(zipBytes).toString();

      final fontItem = makeItem(
        id: 'dup-font',
        family: 'Dup Font',
        filename: 'dup.zip',
        sizeBytes: zipBytes.length,
        sha256: digest,
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => zipBytes,
      );

      expect(
        () => downloader.downloadAndInstall(font: fontItem),
        throwsFormatException,
      );
      expect(storage.isCatalogFontInstalled('dup-font'), isFalse);
    });

    test('cleans up and deletes catalog font if dynamic loader fails', () async {
      final failingLoader = DynamicFontLoader(
        registrar: (family, fonts) async {
          throw Exception('Flutter engine failed to load font');
        },
      );

      final zipBytes = _createZip({
        'Corrupt.ttf': [1, 2, 3],
        'OFL.txt': 'license'.codeUnits,
      });
      final digest = sha256.convert(zipBytes).toString();

      final fontItem = makeItem(
        id: 'corrupt-font',
        family: 'Corrupt Font',
        filename: 'corrupt.zip',
        sizeBytes: zipBytes.length,
        sha256: digest,
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: failingLoader,
        fetcher: (uri, {onProgress}) async => zipBytes,
      );

      expect(
        () => downloader.downloadAndInstall(font: fontItem),
        throwsException,
      );
      expect(storage.isCatalogFontInstalled('corrupt-font'), isFalse);
    });

    test('preserves existing font if new download fails integrity or extraction', () async {
      // First, install a working version
      final goodZip = _createZip({
        'OldVersion.ttf': [10, 20],
        'OFL.txt': 'old license'.codeUnits,
      });
      final goodDigest = sha256.convert(goodZip).toString();

      final goodItem = makeItem(
        id: 'upgrade-font',
        family: 'Upgrade Font',
        filename: 'upgrade.zip',
        sizeBytes: goodZip.length,
        sha256: goodDigest,
      );

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => goodZip,
      );

      await downloader.downloadAndInstall(font: goodItem);
      expect(storage.isCatalogFontInstalled('upgrade-font'), isTrue);

      // Now attempt an update with a broken zip (no font files)
      final brokenZip = _createZip({'readme.txt': [1]});
      final brokenDigest = sha256.convert(brokenZip).toString();

      final brokenItem = makeItem(
        id: 'upgrade-font',
        family: 'Upgrade Font',
        filename: 'upgrade.zip',
        sizeBytes: brokenZip.length,
        sha256: brokenDigest,
      );

      final brokenDownloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async => brokenZip,
      );

      expect(
        () => brokenDownloader.downloadAndInstall(font: brokenItem),
        throwsFormatException,
      );

      // Existing font must still be installed!
      expect(storage.isCatalogFontInstalled('upgrade-font'), isTrue);
      expect(
        storage.listFontFilesForFamily('upgrade-font').map((f) => f.uri.pathSegments.last),
        contains('OldVersion.ttf'),
      );
    });
  });
}
