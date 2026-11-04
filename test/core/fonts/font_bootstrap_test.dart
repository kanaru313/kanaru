import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_bootstrap.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/settings/app_font.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_bootstrap_test_');
    storage = FontStorageService(baseDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('resolveStartupFontId', () {
    test('returns built-in font id directly without disk access', () async {
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async => throw UnimplementedError(),
      );

      expect(
        await resolveStartupFontId(
          fontId: 'inter',
          storage: storage,
          loader: loader,
        ),
        'inter',
      );

      expect(
        await resolveStartupFontId(
          fontId: systemFontId,
          storage: storage,
          loader: loader,
        ),
        systemFontId,
      );

      expect(
        await resolveStartupFontId(
          fontId: defaultFontId,
          storage: storage,
          loader: loader,
        ),
        defaultFontId,
      );
    });

    test('returns catalog font id when installed and loads successfully', () async {
      final dir = storage.fontDirectoryForCatalog('be-vietnam-pro')
        ..createSync(recursive: true);
      File('${dir.path}/BeVietnamPro-Regular.ttf').writeAsBytesSync([1, 2, 3]);

      final loadedFamilies = <String>[];
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async => loadedFamilies.add(family),
      );

      final result = await resolveStartupFontId(
        fontId: 'be-vietnam-pro',
        storage: storage,
        loader: loader,
      );

      expect(result, 'be-vietnam-pro');
      expect(loadedFamilies, contains('Be Vietnam Pro'));
    });

    test('falls back to default font when catalog font is not installed', () async {
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {},
      );

      final result = await resolveStartupFontId(
        fontId: 'be-vietnam-pro',
        storage: storage,
        loader: loader,
      );

      expect(result, defaultFontId);
    });

    test('falls back to default font when catalog font fails to load', () async {
      final dir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${dir.path}/Roboto.ttf').writeAsBytesSync([1]);

      final failingLoader = DynamicFontLoader(
        registrar: (family, fonts) async => throw Exception('Corrupt font'),
      );

      final result = await resolveStartupFontId(
        fontId: 'roboto',
        storage: storage,
        loader: failingLoader,
      );

      expect(result, defaultFontId);
    });

    test('returns custom font id when installed and loads successfully', () async {
      const customId = 'custom_my_font_12345678';
      final dir = storage.fontDirectoryForCustom(customId)
        ..createSync(recursive: true);
      File('${dir.path}/Custom.ttf').writeAsBytesSync([1, 2]);

      final loadedFamilies = <String>[];
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async => loadedFamilies.add(family),
      );

      final result = await resolveStartupFontId(
        fontId: customId,
        storage: storage,
        loader: loader,
      );

      expect(result, customId);
      expect(loadedFamilies, contains(customId));
    });

    test('falls back to default font when custom font is missing', () async {
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {},
      );

      final result = await resolveStartupFontId(
        fontId: 'custom_missing_12345678',
        storage: storage,
        loader: loader,
      );

      expect(result, defaultFontId);
    });

    test('falls back to default font for unknown font id', () async {
      final loader = DynamicFontLoader(
        registrar: (family, fonts) async {},
      );

      final result = await resolveStartupFontId(
        fontId: 'some_random_unknown_id',
        storage: storage,
        loader: loader,
      );

      expect(result, defaultFontId);
    });
  });
}
