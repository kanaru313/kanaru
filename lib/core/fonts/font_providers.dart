import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dynamic_font_loader.dart';
import 'font_downloader_service.dart';
import 'font_storage_service.dart';

final fontStorageServiceProvider =
    Provider<FontStorageService>((ref) => FontStorageService());

final dynamicFontLoaderProvider =
    Provider<DynamicFontLoader>((ref) => DynamicFontLoader());

final fontDownloaderServiceProvider = Provider<FontDownloaderService>((ref) {
  return FontDownloaderService(
    storage: ref.watch(fontStorageServiceProvider),
    fontLoader: ref.watch(dynamicFontLoaderProvider),
  );
});
