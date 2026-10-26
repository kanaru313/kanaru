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

    expect(json['hiddenSidebarTabs'], [
      'albums',
      'artists',
      'folders',
      'languages',
    ]);
    expect(json.containsKey('sidebarTabs'), isFalse);
    expect(decodeDisplayPrefs(json).$1, prefs);
  });

  test('values of the wrong type give the default of that key only', () {
    for (final bad in <Object?>['x', null, <Object?>[], 'abc']) {
      final decoded = decodeDisplayPrefs({
        'colorFromCover': bad,
        'fontScale': bad,
        'hiddenSidebarTabs': bad is List ? 5 : bad,
        'trackNumbersInAlbum': bad,
      }).$1;

      expect(decoded, const DisplayPrefs(), reason: '$bad');
    }
  });

  test('the waveform seek bar is on unless the file says otherwise', () {
    expect(const DisplayPrefs().waveformSeekBar, isTrue);
    expect(decodeDisplayPrefs(<String, Object?>{}).$1.waveformSeekBar, isTrue);
    for (final bad in <Object?>['no', 0, null, <Object?>[]]) {
      expect(
        decodeDisplayPrefs({'waveformSeekBar': bad}).$1.waveformSeekBar,
        isTrue,
        reason: '$bad',
      );
    }
  });

  test('the waveform seek bar round-trips and is not listed as unknown', () {
    final (prefs, extra) = decodeDisplayPrefs({'waveformSeekBar': false});

    expect(prefs.waveformSeekBar, isFalse);
    expect(extra, isEmpty);
    final json = encodeDisplayPrefs(prefs, extra: extra);
    expect(json['waveformSeekBar'], false);
    expect(decodeDisplayPrefs(json).$1, prefs);
    expect(prefs.copyWith(waveformSeekBar: true).waveformSeekBar, isTrue);
    expect(prefs, isNot(const DisplayPrefs()));
  });

  test('unknown keys survive next to the waveform seek bar', () {
    final (prefs, extra) = decodeDisplayPrefs({
      'future': 1,
      'waveformSeekBar': false,
    });

    final json = encodeDisplayPrefs(prefs, extra: extra);

    expect(json['future'], 1);
    expect(json['waveformSeekBar'], false);
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
