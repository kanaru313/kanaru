import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'custom_font_service.dart';
import 'font_providers.dart';

final customFontServiceProvider = Provider<CustomFontService>((ref) {
  return CustomFontService(
    storage: ref.watch(fontStorageServiceProvider),
    fontLoader: ref.watch(dynamicFontLoaderProvider),
  );
});

class CustomFontsNotifier extends Notifier<List<CustomFontItem>> {
  @override
  List<CustomFontItem> build() =>
      ref.watch(customFontServiceProvider).listCustomFonts();

  /// Returns null when the user cancels. Does not change the active font.
  Future<CustomFontItem?> importFromPicker() async {
    final item = await ref.read(customFontServiceProvider).pickAndImportFont();
    if (item != null) {
      ref.invalidateSelf();
    }
    return item;
  }

  Future<void> deleteFont(String fontId) async {
    if (ref.read(settingsProvider).display.fontId == fontId) {
      throw StateError('Cannot delete the active font');
    }
    await ref.read(customFontServiceProvider).deleteCustomFont(fontId);
    ref.invalidateSelf();
  }
}

final customFontsProvider =
    NotifierProvider<CustomFontsNotifier, List<CustomFontItem>>(
  CustomFontsNotifier.new,
);
