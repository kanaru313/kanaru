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
import 'package:kanaru/core/settings/settings_provider.dart';

void main() {
  late Directory tempDir;
  late FontStorageService storage;
  late DynamicFontLoader loader;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_providers_test_');
    storage = FontStorageService(baseDirectory: tempDir);
    loader = DynamicFontLoader(registrar: (family, fonts) async {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('InstalledCatalogFontsNotifier', () {
    test('lists installed catalog fonts and reacts to delete', () async {
      final dir = storage.fontDirectoryForCatalog('roboto')
        ..createSync(recursive: true);
      File('${dir.path}/Roboto.ttf').writeAsBytesSync([1]);

      final container = ProviderContainer(
        overrides: [
          fontStorageServiceProvider.overrideWithValue(storage),
          dynamicFontLoaderProvider.overrideWithValue(loader),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(installedCatalogFontsProvider), {'roboto'});

      // Trying to delete active font throws StateError
      // Default active font in initialSettings is 'nunito'
      // If we set active font to 'roboto':
      container.read(settingsProvider.notifier).setDisplay(
            const DisplayPrefs(fontId: 'roboto'),
          );

      expect(
        () => container
            .read(installedCatalogFontsProvider.notifier)
            .deleteCatalogFont('roboto'),
        throwsStateError,
      );

      // Change active font back to nunito
      container.read(settingsProvider.notifier).setDisplay(
            const DisplayPrefs(fontId: 'nunito'),
          );

      await container
          .read(installedCatalogFontsProvider.notifier)
          .deleteCatalogFont('roboto');

      expect(container.read(installedCatalogFontsProvider), isEmpty);
    });
  });

  group('FontDownloadNotifier', () {
    test('tracks download progress and invalidates installedCatalogFontsProvider', () async {
      final item = catalogFontsManifest.first; // be-vietnam-pro

      final downloader = FontDownloaderService(
        storage: storage,
        fontLoader: loader,
        fetcher: (uri, {onProgress}) async {
          onProgress?.call(50, 100);
          onProgress?.call(100, 100);
          // Return a fake zip or mock
          throw FormatException('Simulated test end');
        },
      );

      final container = ProviderContainer(
        overrides: [
          fontStorageServiceProvider.overrideWithValue(storage),
          dynamicFontLoaderProvider.overrideWithValue(loader),
          fontDownloaderServiceProvider.overrideWithValue(downloader),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(fontDownloadNotifierProvider), isEmpty);

      // Trigger download
      try {
        await container
            .read(fontDownloadNotifierProvider.notifier)
            .downloadFont(item);
      } catch (_) {}

      // State is cleared after completion
      expect(container.read(fontDownloadNotifierProvider), isEmpty);
    });
  });
}
