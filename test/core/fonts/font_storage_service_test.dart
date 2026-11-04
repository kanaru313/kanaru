import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_storage_test_');
    storage = FontStorageService(baseDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FontStorageService directory paths', () {
    test('resolves catalog and custom directories', () {
      expect(storage.catalogDirectory.path, '${tempDir.path}/fonts/catalog');
      expect(storage.customDirectory.path, '${tempDir.path}/fonts/custom');
      expect(
        storage.fontDirectoryForCatalog('roboto').path,
        '${tempDir.path}/fonts/catalog/roboto',
      );
      expect(
        storage.stagingDirectoryForCatalog('roboto').path,
        '${tempDir.path}/fonts/catalog/roboto.tmp',
      );
      expect(
        storage.backupDirectoryForCatalog('roboto').path,
        '${tempDir.path}/fonts/catalog/roboto.old',
      );
      expect(
        storage.fontDirectoryForCustom('custom_my_font').path,
        '${tempDir.path}/fonts/custom/custom_my_font',
      );
    });
  });

  group('listFontFilesForFamily', () {
    test('returns empty when directory does not exist', () {
      expect(storage.listFontFilesForFamily('non_existent'), isEmpty);
    });

    test('returns only ttf and otf files', () {
      final robotoDir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${robotoDir.path}/Roboto-Regular.ttf').writeAsStringSync('ttf-data');
      File('${robotoDir.path}/Roboto-Bold.otf').writeAsStringSync('otf-data');
      File('${robotoDir.path}/OFL.txt').writeAsStringSync('license');
      File('${robotoDir.path}/README.md').writeAsStringSync('readme');

      final fontFiles = storage.listFontFilesForFamily('roboto');
      final filenames = fontFiles.map((f) => f.uri.pathSegments.last).toSet();

      expect(filenames, {'Roboto-Regular.ttf', 'Roboto-Bold.otf'});
      expect(storage.isCatalogFontInstalled('roboto'), isTrue);
    });

    test('works for custom fonts', () {
      final customDir = storage.fontDirectoryForCustom('custom_font_123')
        ..createSync(recursive: true);
      File('${customDir.path}/font.ttf').writeAsStringSync('custom-data');

      final files = storage.listFontFilesForFamily('custom_font_123', isCustom: true);
      expect(files, hasLength(1));
      expect(storage.listCustomFontIds(), contains('custom_font_123'));
    });
  });

  group('listInstalledCatalogFontIds', () {
    test('ignores staging and empty directories', () {
      final robotoDir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${robotoDir.path}/Roboto-Regular.ttf').writeAsStringSync('ttf');

      // Staging directory with font files should be ignored
      final tmpDir = storage.stagingDirectoryForCatalog('lexend')
        ..createSync(recursive: true);
      File('${tmpDir.path}/Lexend.ttf').writeAsStringSync('ttf');

      // Backup directory should be ignored
      final oldDir = storage.backupDirectoryForCatalog('lora')
        ..createSync(recursive: true);
      File('${oldDir.path}/Lora.ttf').writeAsStringSync('ttf');

      // Empty directory should be ignored
      storage.fontDirectoryForCatalog('empty').createSync(recursive: true);

      final installed = storage.listInstalledCatalogFontIds();
      expect(installed, {'roboto'});
    });
  });

  group('readLicenseText', () {
    test('returns null if font directory or license file does not exist', () {
      expect(storage.readLicenseText('missing'), isNull);

      final dir = storage.fontDirectoryForCatalog('nolicense')
        ..createSync(recursive: true);
      File('${dir.path}/font.ttf').writeAsStringSync('ttf');
      expect(storage.readLicenseText('nolicense'), isNull);
    });

    test('reads OFL.txt or LICENSE.txt correctly', () {
      final dir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${dir.path}/OFL.txt').writeAsStringSync('OFL license text');

      expect(storage.readLicenseText('roboto'), 'OFL license text');
    });
  });

  group('deleteCatalogFont', () {
    test('deletes final, tmp, and old directories', () async {
      final finalDir = storage.fontDirectoryForCatalog('test_font')
        ..createSync(recursive: true);
      final tmpDir = storage.stagingDirectoryForCatalog('test_font')
        ..createSync(recursive: true);
      final oldDir = storage.backupDirectoryForCatalog('test_font')
        ..createSync(recursive: true);

      expect(finalDir.existsSync(), isTrue);
      expect(tmpDir.existsSync(), isTrue);
      expect(oldDir.existsSync(), isTrue);

      await storage.deleteCatalogFont('test_font');

      expect(finalDir.existsSync(), isFalse);
      expect(tmpDir.existsSync(), isFalse);
      expect(oldDir.existsSync(), isFalse);
    });
  });

  group('cleanupStaleStaging', () {
    test('deletes .tmp directories unconditionally', () {
      final tmpDir = storage.stagingDirectoryForCatalog('stale_font')
        ..createSync(recursive: true);
      File('${tmpDir.path}/partial.ttf').writeAsStringSync('data');

      storage.cleanupStaleStaging();

      expect(tmpDir.existsSync(), isFalse);
    });

    test('deletes .old directory if final directory exists', () {
      final finalDir = storage.fontDirectoryForCatalog('font1')
        ..createSync(recursive: true);
      final oldDir = storage.backupDirectoryForCatalog('font1')
        ..createSync(recursive: true);

      storage.cleanupStaleStaging();

      expect(finalDir.existsSync(), isTrue);
      expect(oldDir.existsSync(), isFalse);
    });

    test('restores .old directory to final directory if final directory missing', () {
      final oldDir = storage.backupDirectoryForCatalog('interrupted_font')
        ..createSync(recursive: true);
      File('${oldDir.path}/Font-Regular.ttf').writeAsStringSync('font-data');

      final finalDir = storage.fontDirectoryForCatalog('interrupted_font');
      expect(finalDir.existsSync(), isFalse);

      storage.cleanupStaleStaging();

      expect(oldDir.existsSync(), isFalse);
      expect(finalDir.existsSync(), isTrue);
      expect(
        File('${finalDir.path}/Font-Regular.ttf').readAsStringSync(),
        'font-data',
      );
    });
  });
}
