import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/settings_routes.dart';

void main() {
  test('the fixed paths', () {
    expect(settingsRoute, '/settings');
    expect(settingsAppearanceRoute, '/settings/appearance');
    expect(settingsPlaybackRoute, '/settings/playback');
    expect(settingsLibraryRoute, '/settings/library');
    expect(settingsDataRoute, '/settings/data');
    expect(settingsAboutRoute, '/settings/about');
  });

  test('the lyrics sources page is below Playback', () {
    expect(lyricsSourcesRoute, startsWith('$settingsPlaybackRoute/'));
  });
}
