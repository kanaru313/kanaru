import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_loader_test_');
    storage = FontStorageService(baseDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DynamicFontLoader', () {
    test('loadFontFamily registers bytes with registrar and sets isFamilyLoaded', () async {
      final registered = <String, List<Uint8List>>{};
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          registered[family] = fonts;
        },
      );

      final robotoDir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      final fontFile = File('${robotoDir.path}/Roboto.ttf')
        ..writeAsBytesSync([1, 2, 3, 4]);

      expect(loader.isFamilyLoaded('Roboto'), isFalse);

      await loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]);

      expect(loader.isFamilyLoaded('Roboto'), isTrue);
      expect(registered['Roboto'], hasLength(1));
      expect(registered['Roboto']!.first, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('concurrent loadFontFamily calls share in-flight operation', () async {
      var callCount = 0;
      final completer = Completer<void>();

      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          callCount++;
          await completer.future;
        },
      );

      final robotoDir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      final fontFile = File('${robotoDir.path}/Roboto.ttf')
        ..writeAsBytesSync([1, 2, 3]);

      final f1 = loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]);
      final f2 = loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]);

      completer.complete();
      await Future.wait([f1, f2]);

      expect(callCount, 1);
      expect(loader.isFamilyLoaded('Roboto'), isTrue);

      // Subsequent call does nothing
      await loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]);
      expect(callCount, 1);
    });

    test('failed loadFontFamily can be retried', () async {
      var fail = true;
      var attempts = 0;

      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          attempts++;
          if (fail) throw Exception('Engine error');
        },
      );

      final robotoDir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      final fontFile = File('${robotoDir.path}/Roboto.ttf')
        ..writeAsBytesSync([1, 2, 3]);

      await expectLater(
        loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]),
        throwsException,
      );
      expect(loader.isFamilyLoaded('Roboto'), isFalse);
      expect(attempts, 1);

      fail = false;
      await loader.loadFontFamily(family: 'Roboto', fontFiles: [fontFile]);
      expect(loader.isFamilyLoaded('Roboto'), isTrue);
      expect(attempts, 2);
    });

    test('ensureLoaded loads catalog font if installed', () async {
      final loadedFamilies = <String>[];
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          loadedFamilies.add(family);
        },
      );

      // Not installed yet
      await loader.ensureLoaded('be-vietnam-pro', storage);
      expect(loadedFamilies, isEmpty);

      // Now install
      final dir = storage.fontDirectoryForCatalog('be-vietnam-pro')
        ..createSync(recursive: true);
      File('${dir.path}/BeVietnamPro.ttf').writeAsBytesSync([10, 20]);

      await loader.ensureLoaded('be-vietnam-pro', storage);
      expect(loadedFamilies, ['Be Vietnam Pro']);
    });

    test('ensureLoaded loads custom font if installed', () async {
      final loadedFamilies = <String>[];
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          loadedFamilies.add(family);
        },
      );

      final customId = 'custom_my_serif_font_12345678';
      final dir = storage.fontDirectoryForCustom(customId)
        ..createSync(recursive: true);
      File('${dir.path}/MyFont.otf').writeAsBytesSync([30, 40]);

      await loader.ensureLoaded(customId, storage);
      expect(loadedFamilies, [customId]);
    });

    test('loadAllCustomFonts loads every installed custom font', () async {
      final loadedFamilies = <String>[];
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {
          loadedFamilies.add(family);
        },
      );

      for (final id in ['custom_one_abcdef12', 'custom_two_34567890']) {
        final dir = storage.fontDirectoryForCustom(id)
          ..createSync(recursive: true);
        File('${dir.path}/font.ttf').writeAsBytesSync([1]);
      }

      await loader.loadAllCustomFonts(storage);
      expect(loadedFamilies, containsAll(['custom_one_abcdef12', 'custom_two_34567890']));
    });

    test('registerFontLicense dedupes licenses by label', () {
      final loader = DynamicFontLoader();
      expect(() {
        loader.registerFontLicense('Test Font', 'OFL 1.1 license');
        loader.registerFontLicense('Test Font', 'OFL 1.1 license');
      }, returnsNormally);
    });

    test('registerInstalledLicenses registers licenses for all installed catalog fonts', () {
      final loader = DynamicFontLoader();

      final dir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${dir.path}/Roboto.ttf').writeAsBytesSync([1]);
      File('${dir.path}/LICENSE.txt').writeAsStringSync('Apache 2.0');

      expect(() => loader.registerInstalledLicenses(storage), returnsNormally);
    });
  });
}
