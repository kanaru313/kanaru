import 'package:go_router/go_router.dart';

import '../../shared/settings_routes.dart';
import 'about_settings_page.dart';
import 'advanced_settings_page.dart';
import 'appearance_fonts_page.dart';
import 'appearance_settings_page.dart';
import 'data_storage_settings_page.dart';
import 'library_settings_page.dart';
import 'playback_settings_page.dart';

/// The six settings pages below `/settings`, as relative routes (go_router
/// rejects a leading `/` on a nested route); joined they equal the
/// `settings*Route` constants, which a test keeps equal.
///
/// [playbackChildren] are nested under the Playback page: the app's router
/// passes the lyrics sources pages here, so this feature does not know them.
List<RouteBase> settingsSectionRoutes({
  List<RouteBase> playbackChildren = const [],
}) => [
  GoRoute(
    path: _relative(settingsAppearanceRoute),
    builder: (context, state) => AppearanceSettingsPage(focus: _focusOf(state)),
    routes: [
      GoRoute(
        path: settingsAppearanceFontsSegment,
        builder: (context, state) => const AppearanceFontsPage(),
      ),
    ],
  ),
  GoRoute(
    path: _relative(settingsPlaybackRoute),
    builder: (context, state) => PlaybackSettingsPage(focus: _focusOf(state)),
    routes: playbackChildren,
  ),
  GoRoute(
    path: _relative(settingsLibraryRoute),
    builder: (context, state) => LibrarySettingsPage(focus: _focusOf(state)),
  ),
  GoRoute(
    path: _relative(settingsDataRoute),
    builder: (context, state) =>
        DataStorageSettingsPage(focus: _focusOf(state)),
  ),
  GoRoute(
    path: _relative(settingsAdvancedRoute),
    builder: (context, state) => AdvancedSettingsPage(focus: _focusOf(state)),
  ),
  GoRoute(
    path: _relative(settingsAboutRoute),
    builder: (context, state) => AboutSettingsPage(focus: _focusOf(state)),
  ),
];

SettingsAnchor? _focusOf(GoRouterState state) =>
    SettingsAnchor.byId(state.uri.queryParameters[settingsFocusParam]);

String _relative(String route) => route.substring('$settingsRoute/'.length);
