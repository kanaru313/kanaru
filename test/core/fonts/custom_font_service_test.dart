import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/custom_font_service.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

Uint8List _encodeUtf16Be(String text) {
  final result = Uint8List(text.length * 2);
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    result[i * 2] = (code >> 8) & 0xFF;
    result[i * 2 + 1] = code & 0xFF;
  }
  return result;
}

Uint8List _makeValidFontBytes({
  String name = 'Test Font',
  List<int> magic = const [0x00, 0x01, 0x00, 0x00],
}) {
  final nameBytes = _encodeUtf16Be(name);
  final tableDirLength = 12 + 16;
  final nameRecordsLength = 12;
  final nameTableLength = 6 + nameRecordsLength + nameBytes.length;
  final totalLength = tableDirLength + nameTableLength;

  final data = ByteData(totalLength);
  for (var i = 0; i < 4; i++) {
    data.setUint8(i, magic[i]);
  }
  data.setUint16(4, 1); // 1 table

  // 'name' tag
  data.setUint8(12, 0x6E);
  data.setUint8(13, 0x61);
  data.setUint8(14, 0x6D);
  data.setUint8(15, 0x65);
  data.setUint32(20, tableDirLength); // offset
  data.setUint32(24, nameTableLength); // length

  // Name table
  data.setUint16(tableDirLength, 0); // format
  data.setUint16(tableDirLength + 2, 1); // count
  data.setUint16(tableDirLength + 4, 6 + nameRecordsLength); // stringOffset

  final recordOffset = tableDirLength + 6;
  data.setUint16(recordOffset, 3); // platform Windows
  data.setUint16(recordOffset + 2, 1);
  data.setUint16(recordOffset + 4, 0x0409);
  data.setUint16(recordOffset + 6, 1); // nameID 1 (family)
  data.setUint16(recordOffset + 8, nameBytes.length);
  data.setUint16(recordOffset + 10, 0); // string offset

  final storageStart = tableDirLength + 6 + nameRecordsLength;
  for (var i = 0; i < nameBytes.length; i++) {
    data.setUint8(storageStart + i, nameBytes[i]);
  }

  return data.buffer.asUint8List();
}

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late DynamicFontLoader fontLoader;
  late List<String> loadedFamilies;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('custom_font_test_');
    storage = FontStorageService(baseDirectory: tempDir);
    loadedFamilies = [];
    fontLoader = DynamicFontLoader(
      registrar: (family, fonts) async {
        loadedFamilies.add(family);
      },
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CustomFontService.importFontBytes', () {
    test('successfully imports valid TrueType font and writes manifest', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytes = _makeValidFontBytes(name: 'Awesome Sans');
      final item = await service.importFontBytes('AwesomeSans.ttf', bytes);

      expect(item.label, 'Awesome Sans');
      expect(item.id.startsWith('custom_awesome_sans_'), isTrue);
      expect(item.file.existsSync(), isTrue);
      expect(item.file.path.endsWith('.ttf'), isTrue);
      expect(loadedFamilies, contains(item.id));
      expect(fontLoader.isFamilyLoaded(item.id), isTrue);

      final list = service.listCustomFonts();
      expect(list, hasLength(1));
      expect(list.first.id, item.id);
      expect(list.first.label, 'Awesome Sans');
    });

    test('successfully imports OpenType-CFF (.otf) and stores with .otf extension', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytes = _makeValidFontBytes(
        name: 'My OTF Font',
        magic: [0x4F, 0x54, 0x54, 0x4F], // OTTO
      );
      final item = await service.importFontBytes('MyFont.OTF', bytes);

      expect(item.label, 'My OTF Font');
      expect(item.file.path.endsWith('.otf'), isTrue);
      expect(item.file.existsSync(), isTrue);
    });

    test('falls back to filename without extension if name table missing', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      // Valid font header but no name table
      final bytes = Uint8List(12);
      bytes[0] = 0x00;
      bytes[1] = 0x01;
      bytes[2] = 0x00;
      bytes[3] = 0x00;

      final item = await service.importFontBytes('FallbackName.ttf', bytes);
      expect(item.label, 'FallbackName');
      expect(item.id.startsWith('custom_fallbackname_'), isTrue);
    });

    test('handles Vietnamese and CJK names properly in ID and label', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final vnBytes = _makeValidFontBytes(name: 'Phông Chữ Tiếng Việt');
      final itemVn = await service.importFontBytes('font.ttf', vnBytes);
      expect(itemVn.label, 'Phông Chữ Tiếng Việt');
      expect(itemVn.id.startsWith('custom_ph_ng_ch_ti_ng_vi'), isTrue);

      final cjkBytes = _makeValidFontBytes(name: '思源黑体');
      final itemCjk = await service.importFontBytes('font_cjk.ttf', cjkBytes);
      expect(itemCjk.label, '思源黑体');
      // Slug for all non-ascii characters becomes 'font'
      expect(itemCjk.id.startsWith('custom_font_'), isTrue);
    });

    test('rejects files larger than 20MB without writing to disk', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final largeBytes = Uint8List(maxCustomFontBytes + 1);
      await expectLater(
        () => service.importFontBytes('huge.ttf', largeBytes),
        throwsFormatException,
      );

      expect(storage.listCustomFontIds(), isEmpty);
    });

    test('rejects invalid font bytes and leaves nothing on disk', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final badBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      await expectLater(
        () => service.importFontBytes('bad.ttf', badBytes),
        throwsFormatException,
      );

      expect(storage.listCustomFontIds(), isEmpty);
    });

    test('rolls back and cleans up if fontLoader fails', () async {
      final failingLoader = DynamicFontLoader(
        registrar: (family, fonts) async {
          throw Exception('Flutter engine failed to load font');
        },
      );
      final service = CustomFontService(
        storage: storage,
        fontLoader: failingLoader,
      );

      final bytes = _makeValidFontBytes(name: 'Corrupt Engine Font');
      await expectLater(
        () => service.importFontBytes('corrupt.ttf', bytes),
        throwsA(isA<Exception>()),
      );

      // Verify directory was rolled back and manifest is empty
      expect(storage.listCustomFontIds(), isEmpty);
      expect(service.listCustomFonts(), isEmpty);
    });

    test('re-importing identical bytes reuses existing font item', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytes = _makeValidFontBytes(name: 'Dedup Font');
      final first = await service.importFontBytes('first.ttf', bytes);

      final second = await service.importFontBytes('second.ttf', bytes);

      expect(second.id, first.id);
      expect(second.label, first.label);
      expect(second.file.path, first.file.path);
      expect(fontLoader.isFamilyLoaded(first.id), isTrue);
      expect(service.listCustomFonts(), hasLength(1));
    });

    test('importing different bytes with same name yields different IDs', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytes1 = _makeValidFontBytes(name: 'Same Name');
      // Slightly different bytes (append extra byte at end)
      final bytes2 = Uint8List.fromList([...bytes1, 0x42]);

      final item1 = await service.importFontBytes('font1.ttf', bytes1);
      final item2 = await service.importFontBytes('font2.ttf', bytes2);

      expect(item1.id, isNot(item2.id));
      expect(item1.label, item2.label);
      expect(service.listCustomFonts(), hasLength(2));
    });
  });

  group('CustomFontService.deleteCustomFont', () {
    test('removes font files and updates manifest', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytes = _makeValidFontBytes(name: 'Font To Delete');
      final item = await service.importFontBytes('delete_me.ttf', bytes);

      expect(service.listCustomFonts(), hasLength(1));
      expect(item.file.existsSync(), isTrue);

      await service.deleteCustomFont(item.id);

      expect(service.listCustomFonts(), isEmpty);
      expect(item.file.existsSync(), isFalse);
      expect(storage.listCustomFontIds(), isEmpty);
    });
  });

  group('CustomFontService.pickAndImportFont', () {
    test('returns null when picker returns null (user canceled)', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
        picker: () async => null,
      );

      final result = await service.pickAndImportFont();
      expect(result, isNull);
    });

    test('imports font selected by picker', () async {
      final bytes = _makeValidFontBytes(name: 'Picked Font');
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
        picker: () async => (name: 'Picked.ttf', bytes: bytes),
      );

      final result = await service.pickAndImportFont();
      expect(result, isNotNull);
      expect(result!.label, 'Picked Font');
    });
  });

  group('CustomFontService.listCustomFonts', () {
    test('sorts custom fonts alphabetically by label (case-insensitive)', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      final bytesZ = _makeValidFontBytes(name: 'zebra font');
      final bytesA = _makeValidFontBytes(name: 'Apple Font');
      final bytesM = _makeValidFontBytes(name: 'mango font');

      await service.importFontBytes('z.ttf', bytesZ);
      await service.importFontBytes('a.ttf', bytesA);
      await service.importFontBytes('m.ttf', bytesM);

      final list = service.listCustomFonts();
      expect(list.map((f) => f.label).toList(), [
        'Apple Font',
        'mango font',
        'zebra font',
      ]);
    });

    test('falls back to customFontFallbackLabel if manifest entry missing', () async {
      final service = CustomFontService(
        storage: storage,
        fontLoader: fontLoader,
      );

      // Create a directory manually without entry in custom_fonts.json
      final id = 'custom_orphaned_font_12345678';
      final fontDir = storage.fontDirectoryForCustom(id)..createSync(recursive: true);
      File('${fontDir.path}/font.ttf').writeAsBytesSync(_makeValidFontBytes(name: 'Orphan'));

      final list = service.listCustomFonts();
      expect(list, hasLength(1));
      expect(list.first.id, id);
      expect(list.first.label, 'orphaned font');
    });
  });
}
