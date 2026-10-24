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
    expect(d.sidePanelOpen, isFalse);
    expect(d.sidePanelTab, SidePanelTab.queue);
  });

  test('values round-trip, tabs in enum order', () {
    final prefs = DisplayPrefs(
      colorFromCover: true,
      fontScale: 1.25,
      sidebarTabs: {SidebarTab.genres, SidebarTab.songs},
      trackNumbersInAlbum: false,
      sidePanelOpen: true,
      sidePanelTab: SidePanelTab.lyrics,
    );

    final json = encodeDisplayPrefs(prefs);

    expect(json['hiddenSidebarTabs'], [
      'albums',
      'artists',
      'folders',
      'languages',
    ]);
    expect(json.containsKey('sidebarTabs'), isFalse);
    expect(json['sidePanelOpen'], true);
    expect(json['sidePanelTab'], 'lyrics');
    expect(decodeDisplayPrefs(json).$1, prefs);
  });

  test('values of the wrong type give the default of that key only', () {
    for (final bad in <Object?>['x', null, <Object?>[], 'abc']) {
      final decoded = decodeDisplayPrefs({
        'colorFromCover': bad,
        'fontScale': bad,
        'hiddenSidebarTabs': bad is List ? 5 : bad,
        'trackNumbersInAlbum': bad,
        'sidePanelOpen': bad,
        'sidePanelTab': bad,
      }).$1;

      expect(decoded, const DisplayPrefs(), reason: '$bad');
    }
  });

  test('side panel keys: junk falls back per key, known values load', () {
    DisplayPrefs read(Map<String, Object?> m) => decodeDisplayPrefs(m).$1;

    expect(read({'sidePanelTab': 7}).sidePanelTab, SidePanelTab.queue);
    expect(read({'sidePanelTab': 'nope'}).sidePanelTab, SidePanelTab.queue);
    expect(read({'sidePanelOpen': 'yes'}).sidePanelOpen, isFalse);
    expect(read({'sidePanelOpen': 1}).sidePanelOpen, isFalse);
    expect(read({'sidePanelTab': 'lyrics'}).sidePanelTab, SidePanelTab.lyrics);
    expect(read({'sidePanelOpen': true}).sidePanelOpen, isTrue);
    // A bad value of one key leaves the other alone.
    final mixed = read({'sidePanelOpen': true, 'sidePanelTab': 7});
    expect(mixed.sidePanelOpen, isTrue);
    expect(mixed.sidePanelTab, SidePanelTab.queue);
    // Not listed as unknown, so saving does not duplicate them.
    expect(
      decodeDisplayPrefs({'sidePanelOpen': true, 'sidePanelTab': 'x'}).$2,
      isEmpty,
    );
  });

  test('unknown keys are kept next to the side panel keys', () {
    final (prefs, extra) = decodeDisplayPrefs({
      'future': 1,
      'sidePanelOpen': true,
    });

    expect(extra, {'future': 1});
    final json = encodeDisplayPrefs(prefs, extra: extra);
    expect(json['future'], 1);
    expect(json['sidePanelOpen'], true);
    expect(json['sidePanelTab'], 'queue');
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

  test('tabs: a tab not listed as hidden shows; hiding all shows all', () {
    Set<SidebarTab> tabs(Object? v) =>
        decodeDisplayPrefs({'hiddenSidebarTabs': v}).$1.sidebarTabs;
    final all = SidebarTab.values.toSet();

    expect(
      tabs(['songs', 'nope', 'songs', 3]),
      all.difference({SidebarTab.songs}),
    );
    expect(tabs([]), all);
    expect(tabs(['nope']), all);
    expect(tabs('songs'), all);
    expect(tabs([for (final t in SidebarTab.values) t.name]), all);
  });

  test('hidden tab names this version does not know are kept on save', () {
    final (prefs, extra) = decodeDisplayPrefs({
      'hiddenSidebarTabs': ['albums', 'playlists'],
    });

    expect(prefs.sidebarTabs, isNot(contains(SidebarTab.albums)));
    final json = encodeDisplayPrefs(
      prefs.copyWith(sidebarTabs: {...prefs.sidebarTabs, SidebarTab.albums}),
      extra: extra,
    );

    expect(json['hiddenSidebarTabs'], ['playlists']);
  });

  test('the tab set cannot be changed', () {
    final tabs = decodeDisplayPrefs({
      'hiddenSidebarTabs': ['albums'],
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
