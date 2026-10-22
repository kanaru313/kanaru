import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/display_prefs.dart';
import 'package:kanaru/core/settings/display_prefs_codec.dart';

void main() {
  test('missing object or keys give the defaults', () {
    expect(decodeDisplayPrefs(null).$1, const DisplayPrefs());
    expect(decodeDisplayPrefs(<String, Object?>{}).$1, const DisplayPrefs());
    expect(decodeDisplayPrefs('x').$2, isEmpty);
  });

  test('defaults are what the app shows today', () {
    const d = DisplayPrefs();
    expect(d.colorFromCover, isFalse);
    expect(d.fontScale, 1.0);
    expect(d.sidebarTabs, SidebarTab.values.toSet());
    expect(d.trackNumbersInAlbum, isTrue);
  });

  test('values round-trip, tabs in enum order', () {
    final prefs = DisplayPrefs(
      colorFromCover: true,
      fontScale: 1.25,
      sidebarTabs: {SidebarTab.genres, SidebarTab.songs},
      trackNumbersInAlbum: false,
    );

    final json = encodeDisplayPrefs(prefs);

    expect(json['sidebarTabs'], ['songs', 'genres']);
    expect(decodeDisplayPrefs(json).$1, prefs);
  });

  test('values of the wrong type give the default of that key only', () {
    for (final bad in <Object?>['x', null, <Object?>[], 'abc']) {
      final decoded = decodeDisplayPrefs({
        'colorFromCover': bad,
        'fontScale': bad,
        'sidebarTabs': bad is List ? 5 : bad,
        'trackNumbersInAlbum': bad,
      }).$1;

      expect(decoded, const DisplayPrefs(), reason: '$bad');
    }
  });

  test('font scale is moved into range; NaN and infinity give 1.0', () {
    double scale(Object? v) =>
        decodeDisplayPrefs({'fontScale': v}).$1.fontScale;

    expect(scale(0.1), minFontScale);
    expect(scale(9), maxFontScale);
    expect(scale(1), 1.0);
    expect(scale(double.nan), 1.0);
    expect(scale(double.infinity), 1.0);
    expect(scale('1.2'), 1.0);
  });

  test('tabs: unknown names and duplicates go, none left means all', () {
    Set<SidebarTab> tabs(Object? v) =>
        decodeDisplayPrefs({'sidebarTabs': v}).$1.sidebarTabs;

    expect(tabs(['songs', 'nope', 'songs', 3]), {SidebarTab.songs});
    expect(tabs([]), SidebarTab.values.toSet());
    expect(tabs(['nope']), SidebarTab.values.toSet());
    expect(tabs('songs'), SidebarTab.values.toSet());
  });

  test('the tab set cannot be changed', () {
    final tabs = decodeDisplayPrefs({
      'sidebarTabs': ['songs'],
    }).$1.sidebarTabs;

    expect(() => tabs.add(SidebarTab.albums), throwsUnsupportedError);
    expect(
      () => const DisplayPrefs().sidebarTabs.remove(SidebarTab.songs),
      throwsUnsupportedError,
    );
  });

  test('keys this version does not know are kept', () {
    final (prefs, extra) = decodeDisplayPrefs({'density': 'tight'});

    expect(extra, {'density': 'tight'});
    expect(encodeDisplayPrefs(prefs, extra: extra)['density'], 'tight');
  });
}
