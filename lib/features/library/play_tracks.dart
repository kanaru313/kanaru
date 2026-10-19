import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_database.dart' show BrowseTrack;
import '../../core/player/player_service.dart';
import '../../core/player/track.dart';

/// A queue entry for a library row.
Track trackFromItem({
  required String path,
  required String title,
  String? artist,
  int? durationMs,
}) => Track(
  uri: path,
  title: title,
  artist: artist,
  duration: durationMs == null ? null : Duration(milliseconds: durationMs),
);

/// A queue entry for a track of the album or artist pages.
Track trackFromBrowse(BrowseTrack track) => trackFromItem(
  path: track.path,
  title: track.title,
  artist: track.artist,
  durationMs: track.durationMs,
);

/// Replaces the queue with [tracks] and plays from [start]: tapping a row
/// plays its whole context (list, album, artist).
void playTracks(WidgetRef ref, List<Track> tracks, int start) => unawaited(
  ref.read(playerServiceProvider.notifier).openTracks(tracks, start: start),
);
