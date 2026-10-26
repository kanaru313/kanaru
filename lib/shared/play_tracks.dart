import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/library_database.dart' show BrowseTrack;
import '../core/database/library_rows.dart' show TrackListItem;
import '../core/indexer/cover_paths.dart';
import '../core/player/player_service.dart';
import '../core/player/track.dart';

/// A queue entry for a library row. [artPath] is the row's cover thumbnail
/// (see `coverPath`), shown by the player and published over MPRIS; null
/// when the track has no cover or covers are off.
Track trackFromItem({
  required String path,
  required String title,
  String? artist,
  String? album,
  int? year,
  int? durationMs,
  String? artPath,
}) => Track(
  uri: path,
  title: title,
  artist: artist,
  artUri: artPath,
  album: album,
  year: year,
  duration: durationMs == null ? null : Duration(milliseconds: durationMs),
);

/// A queue entry for a track of the album or artist pages, with [artPath]
/// as in [trackFromItem].
Track trackFromBrowse(BrowseTrack track, {String? artPath}) => trackFromItem(
  path: track.path,
  title: track.title,
  artist: track.artist,
  album: track.album,
  year: track.year,
  durationMs: track.durationMs,
  artPath: artPath,
);

/// A queue entry for a library row, with the cover thumbnail from the cover
/// folder [covers] (null when covers are off).
Track trackFromListItem(TrackListItem item, String? covers) => trackFromItem(
  path: item.path,
  title: item.title,
  artist: item.artist,
  album: item.album,
  year: item.year,
  durationMs: item.durationMs,
  artPath: coverPath(covers, item.coverKey),
);

/// Replaces the queue with [tracks] and plays from [start]: tapping a row
/// plays its whole context (list, album, artist).
void playTracks(WidgetRef ref, List<Track> tracks, int start) => unawaited(
  ref.read(playerServiceProvider.notifier).openTracks(tracks, start: start),
);

/// Replaces the queue with [tracks], turns shuffle on and plays from a
/// random one.
void shuffleTracks(WidgetRef ref, List<Track> tracks) =>
    unawaited(ref.read(playerServiceProvider.notifier).openShuffled(tracks));
