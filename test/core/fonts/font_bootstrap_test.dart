import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_bootstrap.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/settings/app_font.dart';

import 'font_test_helpers.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late FakeRegistrar registrar;
  late DynamicFontLoader loader;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('boot_test_');
    storage = FontStorageService(environment: {'XDG_DATA_HOME': tempDir.path});
    registrar = FakeRegistrar();
    loader = DynamicFontLoader(registrar: registrar.call);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<String> resolve(String id) =>
      resolveStartupFontId(fontId: id, storage: storage, loader: loader);

  test('built-in fonts are returned untouched and nothing is loaded', () async {
    expect(await resolve('inter'), 'inter');
    expect(registrar.calls, isEmpty);
  });

  test('an installed catalog font is loaded and kept', () async {
    final dir = storage.fontDirectoryForCatalog('lora')..createSync(recursive: true);
    File('${dir.path}/Lora.ttf').writeAsBytesSync([1]);
    expect(await resolve('lora'), 'lora');
    expect(registrar.calls.single.family, 'Lora');
  });

  test('a catalog font missing from disk falls back to the default', () async {
    expect(await resolve('lora'), defaultFontId);
  });

  test('unknown ids and missing custom fonts fall back to the default', () async {
    expect(await resolve('does-not-exist'), defaultFontId);
    expect(await resolve('${customFontIdPrefix}gone_12345678'), defaultFontId);
  });

  test('a font the engine rejects falls back to the default', () async {
    final dir = storage.fontDirectoryForCatalog('lora')..createSync(recursive: true);
    File('${dir.path}/Lora.ttf').writeAsBytesSync([1]);
    registrar.fail = true;
    expect(await resolve('lora'), defaultFontId);
  });
}
