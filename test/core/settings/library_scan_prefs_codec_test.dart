import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';
import 'package:kanaru/core/settings/library_scan_prefs_codec.dart';

void main() {
  test('missing object or keys give the defaults', () {
    expect(decodeLibraryScanPrefs(null).$1, const LibraryScanPrefs());
    expect(
      decodeLibraryScanPrefs(<String, Object?>{}).$1,
      const LibraryScanPrefs(),
    );
    expect(decodeLibraryScanPrefs('x').$2, isEmpty);
    expect(decodeLibraryScanPrefs([1]).$1, const LibraryScanPrefs());
  });

  test('defaults are what the scan does today', () {
    const d = LibraryScanPrefs();
    expect(d.respectNomedia, isFalse);
    expect(d.duplicatesByFilename, isFalse);
    expect(d.m3uPlaylists, isFalse);
    expect(d.albumGrouping.byAlbumArtist, isTrue);
    expect(d.albumGrouping.byYear, isFalse);
    expect(d.minFileSizeKb, 0);
    expect(d.minDurationSeconds, 0);
  });

  test('values round-trip', () {
    const prefs = LibraryScanPrefs(
      respectNomedia: true,
      duplicatesByFilename: true,
      m3uPlaylists: true,
      albumGrouping: AlbumGrouping(byAlbumArtist: false, byYear: true),
      minFileSizeKb: 1024,
      minDurationSeconds: 30,
    );

    final json = encodeLibraryScanPrefs(prefs);

    expect(decodeLibraryScanPrefs(json).$1, prefs);
    expect(json['albumGrouping'], {'byAlbumArtist': false, 'byYear': true});
  });

  test('values of the wrong type give the default of that key only', () {
    for (final bad in <Object?>['x', null, <Object?>[], 1.5, true]) {
      final decoded = decodeLibraryScanPrefs({
        'respectNomedia': bad is bool ? 'yes' : bad,
        'duplicatesByFilename': true,
        'm3uPlaylists': bad is bool ? 1 : bad,
        'albumGrouping': bad,
        'minFileSizeKb': bad is int ? 'x' : bad,
        'minDurationSeconds': bad,
      }).$1;

      expect(decoded.respectNomedia, isFalse, reason: '$bad');
      expect(decoded.duplicatesByFilename, isTrue, reason: '$bad');
      expect(decoded.m3uPlaylists, isFalse, reason: '$bad');
      expect(decoded.albumGrouping, const AlbumGrouping(), reason: '$bad');
      expect(decoded.minFileSizeKb, 0, reason: '$bad');
      expect(decoded.minDurationSeconds, 0, reason: '$bad');
    }
  });

  test('album grouping falls back on each part', () {
    final grouping = decodeLibraryScanPrefs({
      'albumGrouping': {'byAlbumArtist': 'x', 'byYear': true},
    }).$1.albumGrouping;

    expect(grouping, const AlbumGrouping(byYear: true));
  });

  test('numbers outside the range are moved to the nearest bound', () {
    LibraryScanPrefs decode(int size, int seconds) => decodeLibraryScanPrefs({
      'minFileSizeKb': size,
      'minDurationSeconds': seconds,
    }).$1;

    expect(decode(-5, -1), const LibraryScanPrefs());
    final high = decode(10000000, 100000);
    expect(high.minFileSizeKb, maxMinFileSizeKb);
    expect(high.minDurationSeconds, maxMinDurationSeconds);
    expect(
      decodeLibraryScanPrefs({'minFileSizeKb': 300.0}).$1.minFileSizeKb,
      300,
    );
  });

  test('huge numbers go to the nearest bound, not the default', () {
    final high = decodeLibraryScanPrefs({
      'minFileSizeKb': 1e30,
      'minDurationSeconds': 9007199254740993,
    }).$1;
    final low = decodeLibraryScanPrefs({'minFileSizeKb': -1e30}).$1;

    expect(high.minFileSizeKb, maxMinFileSizeKb);
    expect(high.minDurationSeconds, maxMinDurationSeconds);
    expect(low.minFileSizeKb, 0);
  });

  test('infinity from JSON clamps to the bound and never throws', () {
    final json = jsonDecode(
      '{"minFileSizeKb":1e400,"minDurationSeconds":-1e400}',
    );

    final prefs = decodeLibraryScanPrefs(json).$1;

    expect(prefs.minFileSizeKb, maxMinFileSizeKb);
    expect(prefs.minDurationSeconds, 0);
  });

  test('keys this version does not know inside the grouping are kept', () {
    final (prefs, extra) = decodeLibraryScanPrefs({
      'albumGrouping': {'byYear': true, 'byGenre': true},
    });

    final json = encodeLibraryScanPrefs(prefs, extra: extra);

    expect(json['albumGrouping'], {
      'byGenre': true,
      'byAlbumArtist': true,
      'byYear': true,
    });
    expect(decodeLibraryScanPrefs(json).$1, prefs);
  });

  test('keys this version does not know are kept', () {
    final (prefs, extra) = decodeLibraryScanPrefs({
      'respectNomedia': true,
      'futureKey': {'a': 1},
    });

    expect(extra, {
      'futureKey': {'a': 1},
    });
    final json = encodeLibraryScanPrefs(prefs, extra: extra);
    expect(json['futureKey'], {'a': 1});
    expect(json['respectNomedia'], true);
  });
}
