import '../fonts/font_catalog_manifest.dart';

/// A font the app can use for all its text. Built-in now; fonts downloaded
/// later become more entries (`bundled: false`) loaded with `FontLoader`.
class AppFont {
  const AppFont({
    required this.id,
    required this.label,
    this.family,
    this.licenseAsset,
    this.bundled = true,
  });

  /// Stored in `settings.json`; never changes once shipped.
  final String id;

  /// Proper name of the font; the UI localizes the System entry.
  final String label;

  /// The font family in the theme. System uses the generic 'sans-serif',
  /// which fontconfig resolves to the user's default font.
  final String? family;

  /// Asset holding the license text, shown on the licenses page.
  final String? licenseAsset;

  /// Shipped in the app (as opposed to downloaded later).
  final bool bundled;
}

const systemFontId = 'system';
const defaultFontId = 'nunito';

const builtInAppFonts = <AppFont>[
  // 'sans-serif' (not null): Flutter's default family on Linux is its own
  // list (DejaVu Sans here), while 'sans-serif' follows the fontconfig default.
  AppFont(id: systemFontId, label: 'System', family: 'sans-serif'),
  AppFont(
    id: 'inter',
    label: 'Inter',
    family: 'Inter',
    licenseAsset: 'assets/fonts/OFL.txt',
  ),
  AppFont(
    id: defaultFontId,
    label: 'Nunito',
    family: 'Nunito',
    licenseAsset: 'assets/fonts/Nunito-OFL.txt',
  ),
];

const customFontIdPrefix = 'custom_';

final _validFontIdRegExp = RegExp(r'^[a-zA-Z0-9_-]+$');

/// Validates whether [id] is safe from path traversal and properly formatted.
bool isValidFontId(String? id) =>
    id != null &&
    id.isNotEmpty &&
    id.length <= 128 &&
    _validFontIdRegExp.hasMatch(id);

bool isCustomFontId(String id) =>
    isValidFontId(id) && id.startsWith(customFontIdPrefix);

/// Human readable fallback for a custom id, e.g. `custom_my_font_1a2b3c4d`
/// becomes `my font`. The real label comes from `custom_fonts.json`
/// (see Phase 3 §5); this is only used when that entry is missing.
String customFontFallbackLabel(String id) {
  if (!id.startsWith(customFontIdPrefix)) return id;
  final body = id.substring(customFontIdPrefix.length);
  return body
      .replaceFirst(RegExp(r'_[0-9a-f]{8}$'), '')
      .replaceAll('_', ' ')
      .trim();
}

/// The font with [id]; an unknown id gives the default font (Nunito).
AppFont appFontFor(String id) {
  if (!isValidFontId(id)) {
    return builtInAppFonts.firstWhere((f) => f.id == defaultFontId);
  }
  for (final f in builtInAppFonts) {
    if (f.id == id) return f;
  }
  for (final c in catalogFontsManifest) {
    if (c.id == id) {
      return AppFont(id: c.id, label: c.label, family: c.family, bundled: false);
    }
  }
  if (isCustomFontId(id)) {
    return AppFont(
      id: id,
      label: customFontFallbackLabel(id),
      family: id,
      bundled: false,
    );
  }
  return builtInAppFonts.firstWhere((f) => f.id == defaultFontId);
}
