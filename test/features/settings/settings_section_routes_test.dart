import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/features/settings/settings_section_routes.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

/// The path a [RouteBase] list joins to, one branch deep, under [parent].
List<String> _joined(String parent, List<RouteBase> routes) => [
  for (final route in routes)
    if (route is GoRoute) ...[
      '$parent/${route.path}',
      ..._joined('$parent/${route.path}', route.routes),
    ],
];

void main() {
  test('the section paths join to the shared constants', () {
    expect(_joined(settingsRoute, settingsSectionRoutes()), [
      settingsAppearanceRoute,
      settingsPlaybackRoute,
      settingsLibraryRoute,
      settingsDataRoute,
      settingsAboutRoute,
    ]);
  });

  test('playbackChildren mount under Playback only', () {
    final child = GoRoute(path: 'child', builder: (_, _) => const SizedBox());
    final routes = settingsSectionRoutes(playbackChildren: [child]);

    expect(
      _joined(settingsRoute, routes),
      contains('$settingsPlaybackRoute/child'),
    );
    for (final route in routes.whereType<GoRoute>()) {
      expect(
        route.routes,
        route.path == 'playback' ? [child] : isEmpty,
        reason: route.path,
      );
    }
  });
}
