/// Paths of the screens of translate plugins. Constants and builders only;
/// the router that serves them lives in `lib/app/`.
library;

import 'lyrics_source_routes.dart';
import 'settings_routes.dart';

/// The plugin store as mounted for translation services, a page below
/// Playback settings so that back from it is a pop. It opens on the Translate
/// kind chip.
const translationPluginsRoute = '$settingsPlaybackRoute/translation-plugins';

/// The route pattern of one installed translate plugin's page, below
/// Playback settings. Its path parameter is [lyricsPluginIdParam].
const translationPluginRoutePattern =
    '$settingsPlaybackRoute/translation-plugin/:$lyricsPluginIdParam';

/// The page of the translate plugin installed as [installId].
String translationPluginRoute(String installId) =>
    '$settingsPlaybackRoute/translation-plugin/${Uri.encodeComponent(installId)}';
