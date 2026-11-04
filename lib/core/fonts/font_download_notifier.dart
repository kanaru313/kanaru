import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'font_catalog_manifest.dart';
import 'font_providers.dart';
import 'installed_catalog_fonts_provider.dart';

class FontDownloadNotifier extends Notifier<Map<String, double?>> {
  @override
  Map<String, double?> build() => const {};

  Future<void> downloadFont(CatalogFontItem font) async {
    if (state.containsKey(font.id)) return; // ignore duplicate triggers

    state = {...state, font.id: null};
    var lastPercent = -1;
    try {
      await ref.read(fontDownloaderServiceProvider).downloadAndInstall(
        font: font,
        onProgress: (p) {
          final percent = (p * 100).floor();
          if (percent == lastPercent) return;
          lastPercent = percent;
          state = {...state, font.id: p};
        },
      );
      ref.invalidate(installedCatalogFontsProvider);
    } finally {
      state = {...state}..remove(font.id);
    }
  }
}

final fontDownloadNotifierProvider =
    NotifierProvider<FontDownloadNotifier, Map<String, double?>>(
  FontDownloadNotifier.new,
);
