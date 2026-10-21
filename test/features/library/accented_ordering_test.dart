import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/shared/library_route_keys.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

/// [names] as the screen lists them, top to bottom then left to right.
List<String> _onScreen(WidgetTester tester, List<String> names) {
  Offset at(String name) => tester.getTopLeft(find.text(name));
  return [...names]..sort((a, b) {
    final dy = at(a).dy.compareTo(at(b).dy);
    return dy != 0 ? dy : at(a).dx.compareTo(at(b).dx);
  });
}

void main() {
  // Accented letters sit beside their plain letter, "đ" under D, and a
  // leading "The" of an artist or album name is ignored.
  testWidgets('Albums list orders Vietnamese and European titles', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('t1', artist: 'X', album: 'Zulu'),
      TestTrack('t2', artist: 'X', album: 'Đen Vâu'),
      TestTrack('t3', artist: 'X', album: 'Ánh'),
      TestTrack('t4', artist: 'X', album: 'The Beatles'),
      TestTrack('t5', artist: 'X', album: 'Anh'),
      TestTrack('t6', artist: 'X', album: 'Cam'),
      TestTrack('t7', artist: 'X', album: 'Ølsen'),
    ], location: '/albums');

    const expected = [
      'Anh',
      'Ánh',
      'The Beatles',
      'Cam',
      'Đen Vâu',
      'Ølsen',
      'Zulu',
    ];
    expect(_onScreen(tester, [...expected]..shuffle()), expected);
  });

  testWidgets('Artists list orders Vietnamese and European names', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('t1', artist: 'Zed'),
      TestTrack('t2', artist: 'Đen Vâu'),
      TestTrack('t3', artist: 'Ánh'),
      TestTrack('t4', artist: 'The Beatles'),
      TestTrack('t5', artist: 'Anh'),
      TestTrack('t6', artist: 'Bob'),
      TestTrack('t7', artist: 'Étienne'),
    ], location: '/artists');

    const expected = [
      'Anh',
      'Ánh',
      'The Beatles',
      'Bob',
      'Đen Vâu',
      'Étienne',
      'Zed',
    ];
    expect(_onScreen(tester, [...expected]..shuffle()), expected);
  });

  testWidgets('an artist page orders its albums the same way', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('s1', artist: 'Ann', album: 'Zulu'),
      TestTrack('s2', artist: 'Ann', album: 'Đồng'),
      TestTrack('s3', artist: 'Ann', album: 'The Beta'),
      TestTrack('s4', artist: 'Ann', album: 'Ánh'),
      TestTrack('s5', artist: 'Ann', album: 'Cam'),
      TestTrack('s6', artist: 'Ann', album: 'Anh', year: 2020),
    ], location: artistLocation('ann'));

    // The dated album first, then the others by title.
    const expected = ['Anh', 'Ánh', 'The Beta', 'Cam', 'Đồng', 'Zulu'];
    expect(_onScreen(tester, [...expected]..shuffle()), expected);
  });

  testWidgets('an album page orders tracks without numbers by title', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('The Wall', artist: 'Ann', album: 'Mix'),
      TestTrack('Đêm', artist: 'Ann', album: 'Mix'),
      TestTrack('Ánh y', artist: 'Ann', album: 'Mix'),
      TestTrack('Cầu', artist: 'Ann', album: 'Mix'),
      TestTrack('Anh x', artist: 'Ann', album: 'Mix'),
      TestTrack('Zed', artist: 'Ann', album: 'Mix'),
    ], location: albumLocation(const AlbumKey('ann', 'mix')));

    // Titles keep "The": it sorts under T.
    const expected = ['Anh x', 'Ánh y', 'Cầu', 'Đêm', 'The Wall', 'Zed'];
    expect(_onScreen(tester, [...expected]..shuffle()), expected);
  });
}
