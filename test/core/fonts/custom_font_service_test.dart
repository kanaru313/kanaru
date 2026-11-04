import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/custom_font_service.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/settings/app_font.dart';

import 'font_test_helpers.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late FakeRegistrar registrar;
  late CustomFontService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('custom_font_test_');
    storage = FontStorageService(environment: {'XDG_DATA_HOME': tempDir.path});
    registrar = FakeRegistrar();
    service = CustomFontService(
      storage: storage,
      fontLoader: DynamicFontLoader(registrar: registrar.call),
    );
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('imports a valid font with a content-hash id and its real label', () async {
    final item = await service.importFontBytes('whatever.ttf', buildFont('My Font'));
    expect(item.label, 'My Font');
    expect(item.id, matches(RegExp(r'^custom_my_font_[0-9a-f]{8}$')));
    expect(isCustomFontId(item.id), isTrue);
    expect(service.listCustomFonts().single.label, 'My Font');
  });

  test('importing identical bytes twice is idempotent', () async {
    final bytes = buildFont('Same');
    final a = await service.importFontBytes('a.ttf', bytes);
    final b = await service.importFontBytes('b.ttf', bytes);
    expect(b.id, a.id);
    expect(service.listCustomFonts().length, 1);
  });

  test('same name but different bytes gets a different id', () async {
    final a = await service.importFontBytes('a.ttf', buildFont('Same'));
    final b = await service.importFontBytes('a.ttf', buildFont('Same', pad: 4));
    expect(b.id, isNot(a.id));
    expect(service.listCustomFonts().length, 2);
  });

  test('non-ASCII names still give a readable id and label', () async {
    final item = await service.importFontBytes('x.otf', buildFont('Phông Chữ'));
    expect(item.id, startsWith('custom_ph_ng_ch'));
    expect(item.label, 'Phông Chữ');
  });

  test('uppercase extensions are kept as .otf / .ttf', () async {
    final item = await service.importFontBytes('FONT.OTF', buildFont('Upper'));
    expect(item.file.path, endsWith('.otf'));
  });

  test('rejects non-font bytes and leaves nothing on disk', () async {
    await expectLater(
      service.importFontBytes('x.ttf', Uint8List.fromList(List.filled(64, 1))),
      throwsA(isA<FormatException>()),
    );
    expect(storage.listCustomFontIds(), isEmpty);
  });

  test('rolls back when the engine rejects the font', () async {
    registrar.fail = true;
    await expectLater(
      service.importFontBytes('x.ttf', buildFont('Broken')),
      throwsA(isA<StateError>()),
    );
    expect(storage.listCustomFontIds(), isEmpty);
    expect(service.listCustomFonts(), isEmpty);
  });

  test('delete removes the directory and the manifest entry', () async {
    final item = await service.importFontBytes('x.ttf', buildFont('Gone'));
    await service.deleteCustomFont(item.id);
    expect(service.listCustomFonts(), isEmpty);
    expect(storage.fontDirectoryForCustom(item.id).existsSync(), isFalse);
  });

  test('handles corrupted manifest without wiping metadata and backs up corrupt file', () async {
    final item = await service.importFontBytes('first.ttf', buildFont('First Font'));
    final manifestFile = File('${storage.customDirectory.path}/custom_fonts.json');
    expect(manifestFile.existsSync(), isTrue);

    // Corrupt manifest file
    manifestFile.writeAsStringSync('{ corrupted json content: }}}');

    // Fresh service instance with no prior in-memory cache
    final freshService = CustomFontService(
      storage: storage,
      fontLoader: DynamicFontLoader(registrar: registrar.call),
    );

    // listCustomFonts should not throw and should recover font from directory
    final fonts = freshService.listCustomFonts();
    expect(fonts, hasLength(1));
    expect(fonts.first.id, item.id);

    // Check that backup .corrupt file was created
    final backups = storage.customDirectory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('custom_fonts.json.corrupt.'));
    expect(backups, isNotEmpty);

    // Import a second font; should not wipe the first one
    final item2 = await freshService.importFontBytes('second.ttf', buildFont('Second Font'));
    final allFonts = freshService.listCustomFonts();
    expect(allFonts.map((f) => f.id).toSet(), {item.id, item2.id});
  });

  test('rewriting manifest succeeds when destination file already exists', () async {
    await service.importFontBytes('first.ttf', buildFont('First Font'));
    final manifestFile = File('${storage.customDirectory.path}/custom_fonts.json');
    expect(manifestFile.existsSync(), isTrue);

    // Writing again
    final item2 = await service.importFontBytes('second.ttf', buildFont('Second Font'));
    expect(service.listCustomFonts().map((f) => f.id), contains(item2.id));
  });
}
