import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_catalog_manifest.dart';
import 'package:kanaru/core/fonts/font_download_notifier.dart';
import 'package:kanaru/core/fonts/font_downloader_service.dart';
import 'package:kanaru/core/fonts/font_providers.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/fonts/installed_catalog_fonts_provider.dart';

import 'font_test_helpers.dart';

class _GatedDownloader implements FontDownloaderService {
  _GatedDownloader(this.gate, this.storage);

  final Future<void> gate;
  @override
  final FontStorageService storage;
  @override
  DynamicFontLoader get fontLoader => throw UnimplementedError();
  int calls = 0;

  @override
  Future<void> downloadAndInstall({
    required CatalogFontItem font,
    void Function(double progress)? onProgress,
  }) async {
    calls++;
    await gate;
    final dir = storage.fontDirectoryForCatalog(font.id)..createSync(recursive: true);
    File('${dir.path}/A.ttf').writeAsStringSync('x');
  }
}

void main() {
  test('ignores duplicate triggers, clears state and refreshes the installed list '
      'even when no widget is listening', () async {
    final tempDir = Directory.systemTemp.createTempSync('notifier_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final storage = FontStorageService(environment: {'XDG_DATA_HOME': tempDir.path});

    final gate = Completer<void>();
    final downloader = _GatedDownloader(gate.future, storage);
    final container = ProviderContainer(overrides: [
      fontStorageServiceProvider.overrideWithValue(storage),
      fontDownloaderServiceProvider.overrideWithValue(downloader),
    ]);
    addTearDown(container.dispose);

    expect(container.read(installedCatalogFontsProvider), isEmpty);

    final notifier = container.read(fontDownloadNotifierProvider.notifier);
    final font = testFont('t', createMockZip({'A.ttf': 'x'}));
    final first = notifier.downloadFont(font);
    final second = notifier.downloadFont(font);

    expect(container.read(fontDownloadNotifierProvider).containsKey('t'), isTrue);

    gate.complete();
    await Future.wait([first, second]);

    expect(downloader.calls, 1);
    expect(container.read(fontDownloadNotifierProvider), isEmpty);
    expect(container.read(installedCatalogFontsProvider), contains('t'));
  });
}
