import 'display_prefs.dart';
import 'settings_codec_values.dart';

const _colorFromCoverKey = 'colorFromCover';
const _fontScaleKey = 'fontScale';
const _sidebarTabsKey = 'sidebarTabs';
const _trackNumbersInAlbumKey = 'trackNumbersInAlbum';
const _knownKeys = {
  _colorFromCoverKey,
  _fontScaleKey,
  _sidebarTabsKey,
  _trackNumbersInAlbumKey,
};

/// Reads the `display` object; each key falls back on its own. The second
/// value holds the keys this version does not know.
(DisplayPrefs, Map<String, Object?>) decodeDisplayPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = DisplayPrefs();
  return (
    DisplayPrefs(
      colorFromCover: boolOr(map[_colorFromCoverKey], d.colorFromCover),
      fontScale: doubleInRange(
        map[_fontScaleKey],
        minFontScale,
        maxFontScale,
        d.fontScale,
      ),
      sidebarTabs: _decodeTabs(map[_sidebarTabsKey], d.sidebarTabs),
      trackNumbersInAlbum: boolOr(
        map[_trackNumbersInAlbumKey],
        d.trackNumbersInAlbum,
      ),
    ),
    unknownEntries(map, _knownKeys),
  );
}

/// The known tab names of [json], once each. A list with none (or not a
/// list) gives [fallback]: the sidebar is never left without a tab.
Set<SidebarTab> _decodeTabs(Object? json, Set<SidebarTab> fallback) {
  if (json is! List) return fallback;
  final tabs = {
    for (final tab in SidebarTab.values)
      if (json.contains(tab.name)) tab,
  };
  return tabs.isEmpty ? fallback : Set.unmodifiable(tabs);
}

/// The `display` object, with [extra] (unknown keys) carried over.
Map<String, Object?> encodeDisplayPrefs(
  DisplayPrefs prefs, {
  Map<String, Object?> extra = const {},
}) => {
  ...extra,
  _colorFromCoverKey: prefs.colorFromCover,
  _fontScaleKey: prefs.fontScale,
  // In enum order, whatever order the set was built in.
  _sidebarTabsKey: [
    for (final tab in SidebarTab.values)
      if (prefs.sidebarTabs.contains(tab)) tab.name,
  ],
  _trackNumbersInAlbumKey: prefs.trackNumbersInAlbum,
};
