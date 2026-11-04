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
    expect(settingsAdvancedRoute, '/settings/advanced');
    expect(settingsAboutRoute, '/settings/about');
  });

  test('the lyrics sources page is below Playback', () {
    expect(lyricsSourcesRoute, startsWith('$settingsPlaybackRoute/'));
  });

  group('SettingsAnchor', () {
    test('byId finds known ids and ignores the rest', () {
      for (final anchor in SettingsAnchor.values) {
        expect(SettingsAnchor.byId(anchor.id), anchor);
      }
      expect(SettingsAnchor.byId('nope'), isNull);
      expect(SettingsAnchor.byId(null), isNull);
    });

    test('ids are unique per page', () {
      final keys = SettingsAnchor.values.map((a) => '${a.page}#${a.id}');
      expect(keys.toSet(), hasLength(SettingsAnchor.values.length));
    });
  });

  test('settingsFocusLocation names the page and the anchor', () {
    expect(
      settingsFocusLocation(SettingsAnchor.playbackTranslation),
      '/settings/playback?focus=translation',
    );
    expect(
      settingsFocusLocation(SettingsAnchor.libraryFolders),
      '/settings/library?focus=folders',
    );
    expect(
      settingsFocusLocation(SettingsAnchor.advancedAudio),
      '/settings/advanced?focus=advanced-audio',
    );
    expect(
      settingsFocusLocation(SettingsAnchor.advancedDanger),
      '/settings/advanced?focus=advanced-danger',
    );
  });

  group('withoutSettingsFocus', () {
    test('drops the parameter without leaving a trailing ?', () {
      expect(
        withoutSettingsFocus('/settings/playback?focus=x'),
        '/settings/playback',
      );
    });

    test('keeps other parameters', () {
      expect(
        withoutSettingsFocus('/settings/playback?a=1&focus=x&b=2'),
        '/settings/playback?a=1&b=2',
      );
    });

    test('keeps repeated parameters and the fragment', () {
      expect(
        withoutSettingsFocus('/settings/playback?focus=x&a=1&a=2#f'),
        '/settings/playback?a=1&a=2#f',
      );
      expect(
        withoutSettingsFocus('/settings/playback?focus=x#f'),
        '/settings/playback#f',
      );
    });

    test('returns a location without it byte for byte', () {
      const item = '/settings/plugins/item/some%20id%2Fx?repo=a%2Fb';
      expect(withoutSettingsFocus(item), same(item));
      expect(withoutSettingsFocus('/settings/library'), '/settings/library');
    });

    test('leaves other screens alone', () {
      expect(withoutSettingsFocus('/songs?focus=x'), '/songs?focus=x');
    });
  });
}
