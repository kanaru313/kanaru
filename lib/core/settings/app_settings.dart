/// Light or dark theme, or whatever the desktop uses.
enum ThemePreference { system, light, dark }

/// Who draws the window's title bar.
enum TitleBarPreference {
  /// Kanaru's own top bar with window buttons.
  kanaru,

  /// The native one. On Wayland that is GTK's header bar, since the runner
  /// always creates one there.
  system,

  /// None at all, for tiling window managers that draw no decorations.
  none,
}

/// The user's preferences, as stored in `settings.json`.
///
/// Only non-secret preferences belong here: the file is plain text and may
/// be attached to bug reports. Credentials go to the system keyring.
class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.languageCode,
    this.titleBar = TitleBarPreference.kanaru,
  });

  final ThemePreference theme;

  /// UI language such as `vi`, or `null` to follow the system. Whether the
  /// app has a translation for it is decided by the app, not here.
  final String? languageCode;

  final TitleBarPreference titleBar;

  AppSettings copyWith({ThemePreference? theme, TitleBarPreference? titleBar}) =>
      AppSettings(
        theme: theme ?? this.theme,
        languageCode: languageCode,
        titleBar: titleBar ?? this.titleBar,
      );

  /// Separate from [copyWith] because `null` is a valid language here.
  AppSettings withLanguage(String? languageCode) => AppSettings(
    theme: theme,
    languageCode: languageCode,
    titleBar: titleBar,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.languageCode == languageCode &&
      other.titleBar == titleBar;

  @override
  int get hashCode => Object.hash(theme, languageCode, titleBar);

  @override
  String toString() =>
      'AppSettings(theme: ${theme.name}, language: $languageCode, '
      'titleBar: ${titleBar.name})';
}
