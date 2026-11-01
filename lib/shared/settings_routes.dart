/// Paths of the Settings pages. Constants only; the routes that serve them
/// live in `lib/features/settings/` and `lib/app/`.
library;

/// The Settings root: one tile per category.
const settingsRoute = '/settings';

const settingsAppearanceRoute = '$settingsRoute/appearance';
const settingsPlaybackRoute = '$settingsRoute/playback';
const settingsLibraryRoute = '$settingsRoute/library';
const settingsDataRoute = '$settingsRoute/data';
const settingsAboutRoute = '$settingsRoute/about';

/// Query parameter naming the anchor a Settings link opens.
const settingsFocusParam = 'focus';

/// Places a link can open in Settings: a group or one row, on [page].
enum SettingsAnchor {
  playbackTranslation('translation', settingsPlaybackRoute),
  playbackLyrics('lyrics', settingsPlaybackRoute),
  libraryFolders('folders', settingsLibraryRoute);

  const SettingsAnchor(this.id, this.page);

  /// Value of the [settingsFocusParam] query parameter.
  final String id;

  /// Route of the page holding the anchor.
  final String page;

  /// The anchor named [id], or `null` when [id] is null or unknown.
  static SettingsAnchor? byId(String? id) {
    for (final anchor in values) {
      if (anchor.id == id) return anchor;
    }
    return null;
  }
}

/// Location that opens [anchor]'s page with the anchor in view.
String settingsFocusLocation(SettingsAnchor anchor) => Uri(
  path: anchor.page,
  queryParameters: {settingsFocusParam: anchor.id},
).toString();

/// [location] without the [settingsFocusParam] parameter. A location without
/// it (or outside Settings) is returned unchanged, byte for byte.
String withoutSettingsFocus(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null ||
      !uri.queryParameters.containsKey(settingsFocusParam) ||
      !(uri.path == settingsRoute || uri.path.startsWith('$settingsRoute/'))) {
    return location;
  }
  final rest = {...uri.queryParametersAll}..remove(settingsFocusParam);
  return Uri(
    path: uri.path,
    queryParameters: rest.isEmpty ? null : rest,
    fragment: uri.hasFragment ? uri.fragment : null,
  ).toString();
}
