import 'package:logging/logging.dart';

import '../settings/app_font.dart';
import 'dynamic_font_loader.dart';
import 'font_catalog_manifest.dart';
import 'font_storage_service.dart';

final _log = Logger('font_bootstrap');

/// Returns the font id the app should start with. Loads the font into the
/// engine when it is an installed catalog/custom font; falls back to the
/// default font when it is unknown, missing on disk or fails to load.
Future<String> resolveStartupFontId({
  required String fontId,
  required FontStorageService storage,
  required DynamicFontLoader loader,
}) async {
  if (builtInAppFonts.any((f) => f.id == fontId)) return fontId;
  try {
    final isCatalog = catalogFontsManifest.any((c) => c.id == fontId);
    if (!isCatalog && !isCustomFontId(fontId)) return defaultFontId;

    final files = storage.listFontFilesForFamily(fontId, isCustom: !isCatalog);
    if (files.isEmpty) return defaultFontId;

    await loader.ensureLoaded(fontId, storage);
    return fontId;
  } catch (e, st) {
    _log.warning('Startup font "$fontId" unusable, falling back', e, st);
    return defaultFontId;
  }
}
