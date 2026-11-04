import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'font_providers.dart';

class InstalledCatalogFontsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref.watch(fontStorageServiceProvider).listInstalledCatalogFontIds();

  Future<void> deleteCatalogFont(String fontId) async {
    if (ref.read(settingsProvider).display.fontId == fontId) {
      throw StateError('Cannot delete the active font');
    }
    await ref.read(fontStorageServiceProvider).deleteCatalogFont(fontId);
    ref.invalidateSelf();
  }
}

final installedCatalogFontsProvider =
    NotifierProvider<InstalledCatalogFontsNotifier, Set<String>>(
  InstalledCatalogFontsNotifier.new,
);
