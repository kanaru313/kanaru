import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/custom_font_providers.dart';
import 'package:kanaru/core/fonts/custom_font_service.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_providers.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

Uint8List _makeValidFontBytes({String name = 'Test Font'}) {
  final nameBytes = Uint8List(name.length * 2);
  for (var i = 0; i < name.length; i++) {
    final code = name.codeUnitAt(i);
    nameBytes[i * 2] = (code >> 8) & 0xFF;
    nameBytes[i * 2 + 1] = code & 0xFF;
  }
  final tableDirLength = 12 + 16;
  final nameRecordsLength = 12;
  final nameTableLength = 6 + nameRecordsLength + nameBytes.length;
  final totalLength = tableDirLength + nameTableLength;

  final data = ByteData(totalLength);
  data.setUint8(0, 0x00);
  data.setUint8(1, 0x01);
  data.setUint8(2, 0x00);
  data.setUint8(3, 0x00);
  data.setUint16(4, 1);

  data.setUint8(12, 0x6E);
  data.setUint8(13, 0x61);
  data.setUint8(14, 0x6D);
  data.setUint8(15, 0x65);
  data.setUint32(20, tableDirLength);
  data.setUint32(24, nameTableLength);

  data.setUint16(tableDirLength, 0);
  data.setUint16(tableDirLength + 2, 1);
  data.setUint16(tableDirLength + 4, 6 + nameRecordsLength);

  final recordOffset = tableDirLength + 6;
  data.setUint16(recordOffset, 3);
  data.setUint16(recordOffset + 2, 1);
  data.setUint16(recordOffset + 4, 0x0409);
  data.setUint16(recordOffset + 6, 1);
  data.setUint16(recordOffset + 8, nameBytes.length);
  data.setUint16(recordOffset + 10, 0);

  final storageStart = tableDirLength + 6 + nameRecordsLength;
  for (var i = 0; i < nameBytes.length; i++) {
    data.setUint8(storageStart + i, nameBytes[i]);
  }

  return data.buffer.asUint8List();
}

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late DynamicFontLoader loader;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('custom_font_providers_test_');
    storage = FontStorageService(baseDirectory: tempDir);
    loader = DynamicFontLoader(registrar: (family, fonts) async {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('customFontServiceProvider', () {
    test('provides a functional CustomFontService', () {
      final container = ProviderContainer(
        overrides: [
          fontStorageServiceProvider.overrideWithValue(storage),
          dynamicFontLoaderProvider.overrideWithValue(loader),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(customFontServiceProvider);
      expect(service, isNotNull);
      expect(service.listCustomFonts(), isEmpty);
    });
  });

  group('CustomFontsNotifier', () {
    test('builds empty list initially, updates on import and delete', () async {
      PickedFontFile? nextPicked;
      final customService = CustomFontService(
        storage: storage,
        fontLoader: loader,
        picker: () async => nextPicked,
      );

      final container = ProviderContainer(
        overrides: [
          fontStorageServiceProvider.overrideWithValue(storage),
          dynamicFontLoaderProvider.overrideWithValue(loader),
          customFontServiceProvider.overrideWithValue(customService),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(customFontsProvider), isEmpty);

      // Picker returns null (cancelled)
      nextPicked = null;
      final cancelResult =
          await container.read(customFontsProvider.notifier).importFromPicker();
      expect(cancelResult, isNull);
      expect(container.read(customFontsProvider), isEmpty);

      // Picker returns valid font
      final fontBytes = _makeValidFontBytes(name: 'Provider Font');
      nextPicked = (name: 'ProviderFont.ttf', bytes: fontBytes);

      final item =
          await container.read(customFontsProvider.notifier).importFromPicker();
      expect(item, isNotNull);
      expect(item!.label, 'Provider Font');

      final list = container.read(customFontsProvider);
      expect(list, hasLength(1));
      expect(list.first.id, item.id);

      // Attempt to delete when active font
      container.read(settingsProvider.notifier).setDisplay(
            DisplayPrefs(fontId: item.id),
          );

      expect(
        () => container.read(customFontsProvider.notifier).deleteFont(item.id),
        throwsStateError,
      );

      // Switch active font to default font ('nunito') and delete
      container.read(settingsProvider.notifier).setDisplay(
            const DisplayPrefs(fontId: 'nunito'),
          );

      await container.read(customFontsProvider.notifier).deleteFont(item.id);
      expect(container.read(customFontsProvider), isEmpty);
    });
  });
}
