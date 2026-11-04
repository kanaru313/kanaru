import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_downloader_service.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';

import 'font_test_helpers.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late FakeRegistrar registrar;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_test_');
    storage = FontStorageService(environment: {'XDG_DATA_HOME': tempDir.path});
    registrar = FakeRegistrar();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  FontDownloaderService serviceFor(Uint8List zip) => FontDownloaderService(
        storage: storage,
        fontLoader: DynamicFontLoader(registrar: registrar.call),
        fetcher: (uri, {onProgress}) async => zip,
      );

  void expectNoStaging(String id) {
    expect(storage.stagingDirectoryForCatalog(id).existsSync(), isFalse);
    expect(storage.backupDirectoryForCatalog(id).existsSync(), isFalse);
  }

  test('installs only fonts and license, registers one family with all weights', () async {
    final zip = createMockZip({
      'Test-Regular.ttf': 'a',
      'Test-Bold.ttf': 'b',
      'OFL.txt': 'license',
      'readme.md': 'ignored',
    });
    await serviceFor(zip).downloadAndInstall(font: testFont('t', zip));

    final dir = storage.fontDirectoryForCatalog('t');
    expect(dir.listSync().map(baseName).toSet(),
        {'Test-Regular.ttf', 'Test-Bold.ttf', 'OFL.txt'});
    expectNoStaging('t');
    expect(registrar.calls.single.family, 'Test Font');
    expect(registrar.calls.single.fileCount, 2);
    expect(storage.isCatalogFontInstalled('t'), isTrue);
  });

  test('rejects a SHA-256 mismatch and installs nothing', () async {
    final zip = createMockZip({'A.ttf': 'a'});
    await expectLater(
      serviceFor(zip).downloadAndInstall(font: testFont('t', zip, sha: '0' * 64)),
      throwsA(isA<FormatException>()),
    );
    expect(storage.fontDirectoryForCatalog('t').existsSync(), isFalse);
    expectNoStaging('t');
  });

  for (final bad in {
    'path traversal': {'../evil.ttf': 'x'},
    'duplicate names': {'a/X.ttf': '1', 'b/X.ttf': '2'},
    'no font files': {'OFL.txt': 'license'},
  }.entries) {
    test('rejects zip with ${bad.key} and cleans staging', () async {
      final zip = createMockZip(bad.value);
      await expectLater(
        serviceFor(zip).downloadAndInstall(font: testFont('t', zip)),
        throwsA(isA<FormatException>()),
      );
      expect(storage.fontDirectoryForCatalog('t').existsSync(), isFalse);
      expectNoStaging('t');
    });
  }

  test('a failed update keeps the previous install untouched', () async {
    final previous = storage.fontDirectoryForCatalog('t')..createSync(recursive: true);
    File('${previous.path}/Old.ttf').writeAsStringSync('old');

    final zip = createMockZip({'../evil.ttf': 'x'});
    await expectLater(
      serviceFor(zip).downloadAndInstall(font: testFont('t', zip)),
      throwsA(isA<FormatException>()),
    );
    expect(File('${previous.path}/Old.ttf').existsSync(), isTrue);
    expectNoStaging('t');
  });

  test('a successful update replaces the previous install', () async {
    final previous = storage.fontDirectoryForCatalog('t')..createSync(recursive: true);
    File('${previous.path}/Old.ttf').writeAsStringSync('old');

    final zip = createMockZip({'New.ttf': 'new'});
    await serviceFor(zip).downloadAndInstall(font: testFont('t', zip));

    expect(File('${previous.path}/Old.ttf').existsSync(), isFalse);
    expect(File('${previous.path}/New.ttf').existsSync(), isTrue);
    expectNoStaging('t');
  });

  test('progress falls back to the manifest size when content length is unknown', () async {
    final zip = createMockZip({'A.ttf': 'a'});
    final seen = <double>[];
    final service = FontDownloaderService(
      storage: storage,
      fontLoader: DynamicFontLoader(registrar: registrar.call),
      fetcher: (uri, {onProgress}) async {
        onProgress?.call(zip.length ~/ 2, 0); // total unknown
        return zip;
      },
    );
    await service.downloadAndInstall(font: testFont('t', zip), onProgress: seen.add);
    expect(seen.single, closeTo(0.5, 0.05));
  });

  test('cleanupStaleStaging restores an interrupted swap and removes tmp dirs', () async {
    final old = storage.backupDirectoryForCatalog('a')..createSync(recursive: true);
    File('${old.path}/A.ttf').writeAsStringSync('x');
    storage.stagingDirectoryForCatalog('b').createSync(recursive: true);

    storage.cleanupStaleStaging();

    expect(storage.isCatalogFontInstalled('a'), isTrue); // .old restored
    expect(storage.backupDirectoryForCatalog('a').existsSync(), isFalse);
    expect(storage.stagingDirectoryForCatalog('b').existsSync(), isFalse);
  });
}
