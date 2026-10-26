import 'display_prefs.dart';
import 'settings_codec_values.dart';

const _colorFromCoverKey = 'colorFromCover';
const _waveformSeekBarKey = 'waveformSeekBar';
const _fontScaleKey = 'fontScale';
const _hiddenSidebarTabsKey = 'hiddenSidebarTabs';
const _trackNumbersInAlbumKey = 'trackNumbersInAlbum';
final Set<SidebarTab> _allTabs = const DisplayPrefs().sidebarTabs;
const _knownKeys = {
  _colorFromCoverKey,
  _waveformSeekBarKey,
  _fontScaleKey,
  _hiddenSidebarTabsKey,
  _trackNumbersInAlbumKey,
};

/// Reads the `display` object; each key falls back on its own. The second
/// value holds the keys this version does not know, plus (under
/// `hiddenSidebarTabs`) the tab names it does not know, so that saving
/// keeps them.
(DisplayPrefs, Map<String, Object?>) decodeDisplayPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = DisplayPrefs();
  final (tabs, unknownHidden) = _decodeTabs(map[_hiddenSidebarTabsKey]);
  return (
    DisplayPrefs(
      colorFromCover: boolOr(map[_colorFromCoverKey], d.colorFromCover),
      waveformSeekBar: boolOr(map[_waveformSeekBarKey], d.waveformSeekBar),
      fontScale: doubleInRange(
        map[_fontScaleKey],
        minFontScale,
        maxFontScale,
        d.fontScale,
      ),
      sidebarTabs: tabs,
      trackNumbersInAlbum: boolOr(
        map[_trackNumbersInAlbumKey],
        d.trackNumbersInAlbum,
      ),
    ),
    {
      ...unknownEntries(map, _knownKeys),
      if (unknownHidden.isNotEmpty) _hiddenSidebarTabsKey: unknownHidden,
    },
  );
}

/// The tabs that show, given the stored list of hidden ones (a tab that is
/// not listed shows, so a tab added by a newer version shows by default),
/// and the hidden names this version does not know. A list that hides every
/// tab (or not a list) shows them all: the sidebar is never left empty.
(Set<SidebarTab>, List<Object?>) _decodeTabs(Object? json) {
  if (json is! List) return (_allTabs, const []);
  final hidden = {
    for (final tab in SidebarTab.values)
      if (json.contains(tab.name)) tab,
  };
  final unknown = [
    for (final name in json)
      if (name is String && !SidebarTab.values.any((t) => t.name == name)) name,
  ];
  final shown = _allTabs.difference(hidden);
  return (shown.isEmpty ? _allTabs : Set.unmodifiable(shown), unknown);
}

/// The `display` object, with [extra] (unknown keys) carried over.
Map<String, Object?> encodeDisplayPrefs(
  DisplayPrefs prefs, {
  Map<String, Object?> extra = const {},
}) {
  final unknownHidden = extra[_hiddenSidebarTabsKey];
  return {
    ...extra,
    _colorFromCoverKey: prefs.colorFromCover,
    _waveformSeekBarKey: prefs.waveformSeekBar,
    _fontScaleKey: prefs.fontScale,
    // In enum order, whatever order the set was built in; names this version
    // does not know stay hidden.
    _hiddenSidebarTabsKey: [
      for (final tab in SidebarTab.values)
        if (!prefs.sidebarTabs.contains(tab)) tab.name,
      if (unknownHidden is List) ...unknownHidden,
    ],
    _trackNumbersInAlbumKey: prefs.trackNumbersInAlbum,
  };
}
