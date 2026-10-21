import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';

/// Vietnamese and plain tracks: "son tung" finds a song, an album and an
/// artist; "adele" finds only a song group.
const searchTracks = [
  TestTrack(
    'Lạc Trôi',
    artist: 'Sơn Tùng M-TP',
    album: 'Sky Tour',
    albumArtist: 'Sơn Tùng M-TP',
    track: 1,
  ),
  TestTrack(
    'Chạy Ngay Đi',
    artist: 'Sơn Tùng M-TP',
    album: 'Sky Tour',
    albumArtist: 'Sơn Tùng M-TP',
    track: 2,
  ),
  TestTrack('Hello', artist: 'Adele', album: '25', albumArtist: 'Adele'),
];

/// Opens the search page for [query] with [tracks] stored.
Future<void> openSearch(
  WidgetTester tester,
  LibraryHarness h,
  String query, {
  List<TestTrack> tracks = searchTracks,
}) => openWithTracks(
  tester,
  h,
  tracks,
  location: '/search?q=${Uri.encodeQueryComponent(query)}',
);

/// Titles in the player queue.
List<String> queuedTitles(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.tracks) t.title,
];
