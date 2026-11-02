import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/song_row.dart';
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

/// A queue entry for a library row, with the cover thumbnail from the cover
/// folder [covers] (null when covers are off).
Track trackFromRow(SongRow row, String? covers) => trackFromItem(
  path: row.path,
  title: row.title,
  artist: row.artist,
  album: row.album,
  year: row.year,
  durationMs: row.durationMs,
  artPath: coverPath(covers, row.coverKey),
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
