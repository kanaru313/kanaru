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

  /// The font family in the theme; null leaves the platform default
  /// (fontconfig).
  final String? family;

  /// Asset holding the license text, shown on the licenses page.
  final String? licenseAsset;

  /// Shipped in the app (as opposed to downloaded later).
  final bool bundled;
}

const systemFontId = 'system';
const defaultFontId = 'inter';

const builtInAppFonts = <AppFont>[
  AppFont(id: systemFontId, label: 'System'),
  AppFont(
    id: defaultFontId,
    label: 'Inter',
    family: 'Inter',
    licenseAsset: 'assets/fonts/OFL.txt',
  ),
  AppFont(
    id: 'nunito',
    label: 'Nunito',
    family: 'Nunito',
    licenseAsset: 'assets/fonts/Nunito-OFL.txt',
  ),
];

/// The font with [id]; an unknown id gives Inter.
AppFont appFontFor(String id) => builtInAppFonts.firstWhere(
  (f) => f.id == id,
  orElse: () => builtInAppFonts.firstWhere((f) => f.id == defaultFontId),
);
