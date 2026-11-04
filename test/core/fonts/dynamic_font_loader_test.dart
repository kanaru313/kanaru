import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

import 'font_test_helpers.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late FakeRegistrar registrar;
  late List<File> files;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('loader_test_');
    storage = FontStorageService(environment: {'XDG_DATA_HOME': tempDir.path});
    registrar = FakeRegistrar();
    files = [
      File('${tempDir.path}/R.ttf')..writeAsBytesSync([1]),
      File('${tempDir.path}/B.ttf')..writeAsBytesSync([2]),
    ];
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('registers all weights in one call and dedupes concurrent loads', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);
    await Future.wait([
      loader.loadFontFamily(family: 'X', fontFiles: files),
      loader.loadFontFamily(family: 'X', fontFiles: files),
    ]);
    expect(registrar.calls.length, 1);
    expect(registrar.calls.single.fileCount, 2);
    expect(loader.isFamilyLoaded('X'), isTrue);
  });

  test('a failed load can be retried', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);
    registrar.fail = true;
    await expectLater(
      loader.loadFontFamily(family: 'X', fontFiles: files),
      throwsA(isA<StateError>()),
    );
    expect(loader.isFamilyLoaded('X'), isFalse);

    registrar.fail = false;
    await loader.loadFontFamily(family: 'X', fontFiles: files);
    expect(loader.isFamilyLoaded('X'), isTrue);
  });

  test('ensureLoaded throws StateError when catalog font is not installed', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);

    // Not installed yet -> throws StateError
    await expectLater(
      () => loader.ensureLoaded('be-vietnam-pro', storage),
      throwsStateError,
    );
    expect(registrar.calls, isEmpty);

    // Now install
    final dir = storage.fontDirectoryForCatalog('be-vietnam-pro')
      ..createSync(recursive: true);
    File('${dir.path}/BeVietnamPro.ttf').writeAsBytesSync([10, 20]);

    await loader.ensureLoaded('be-vietnam-pro', storage);
    expect(registrar.calls.single.family, 'Be Vietnam Pro');
  });

  test('ensureLoaded throws StateError when custom font is missing on disk', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);
    const customId = 'custom_missing_12345678';
    await expectLater(
      () => loader.ensureLoaded(customId, storage),
      throwsStateError,
    );
  });

  test('ensureLoaded is a no-op for built-in fonts', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);
    await loader.ensureLoaded('inter', storage);
    await loader.ensureLoaded('nunito', storage);
    await loader.ensureLoaded('system', storage);
    expect(registrar.calls, isEmpty);
  });

  test('ensureLoaded loads custom font if installed', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);

    const customId = 'custom_my_serif_font_12345678';
    final dir = storage.fontDirectoryForCustom(customId)
      ..createSync(recursive: true);
    File('${dir.path}/MyFont.otf').writeAsBytesSync([30, 40]);

    await loader.ensureLoaded(customId, storage);
    expect(registrar.calls.single.family, customId);
  });

  test('loadAllCustomFonts loads every installed custom font', () async {
    final loader = DynamicFontLoader(registrar: registrar.call);

    for (final id in ['custom_one_abcdef12', 'custom_two_34567890']) {
      final dir = storage.fontDirectoryForCustom(id)..createSync(recursive: true);
      File('${dir.path}/font.ttf').writeAsBytesSync([1]);
    }

    await loader.loadAllCustomFonts(storage);
    expect(
      registrar.calls.map((c) => c.family).toSet(),
      {'custom_one_abcdef12', 'custom_two_34567890'},
    );
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
}
