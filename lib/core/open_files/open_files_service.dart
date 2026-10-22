import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../indexer/indexer_providers.dart';
import '../indexer/library_indexer.dart' show maxTagBatchSize;
import '../indexer/tag_reader.dart';
import '../paths/local_audio_path.dart';
import '../player/player_service.dart';
import '../player/track.dart';

final _log = Logger('open_files');

/// Most paths one request may play; the rest are dropped.
const maxOpenFiles = 1000;

/// How long one tag batch may take before the files play under their file
/// names instead.
const _defaultTagTimeout = Duration(seconds: 5);

/// Plays files that come from outside the library: the command line and
/// "Open with".
class OpenFilesService {
  OpenFilesService(this._ref, {this.tagTimeout = _defaultTagTimeout});

  final Ref _ref;
  final Duration tagTimeout;

  /// Requests received so far; a request's number is its arrival order.
  int _arrivals = 0;

  /// Number of the newest request that has at least one playable path. Only
  /// such a request replaces another: a request where nothing passes (a typo,
  /// a text file) must not cancel one that is about to play. A request that
  /// finds a newer valid one gives up, so only the newest reaches the player.
  int _newestValid = 0;

  /// A tag call timed out and has not returned yet. The native pool may be
  /// stuck on it, so no new call is made until it returns.
  bool _readerStuck = false;

  /// Replaces the queue with the audio files among [rawPaths] and plays the
  /// first, in the order given. Each entry is an absolute path or a `file:`
  /// URI (the runner makes command-line paths absolute); everything else is
  /// dropped, see [localAudioPath]. Returns the number of tracks opened: 0 when
  /// nothing passed or a newer request took over. A request where nothing
  /// passed leaves the queue and any earlier request alone.
  Future<int> open(List<String> rawPaths) async {
    final arrival = ++_arrivals;
    var raw = rawPaths;
    if (raw.length > maxOpenFiles) {
      _log.warning(
        'Opening only the first $maxOpenFiles of ${raw.length} files',
      );
      raw = raw.sublist(0, maxOpenFiles);
    }

    final paths = <String>[];
    for (final entry in raw) {
      final path = await localAudioPath(entry);
      if (_newestValid > arrival) return 0;
      if (path == null) {
        _log.info('Not a local audio file, skipped: $entry');
      } else {
        paths.add(path);
      }
    }
    if (paths.isEmpty) return 0;
    _newestValid = arrival;

    final tracks = <Track>[];
    for (var i = 0; i < paths.length; i += maxTagBatchSize) {
      final end = i + maxTagBatchSize;
      final batch = paths.sublist(i, end > paths.length ? paths.length : end);
      tracks.addAll(await _tracksOf(batch));
      if (_newestValid != arrival) return 0;
    }

    await _ref.read(playerServiceProvider.notifier).openTracks(tracks);
    return tracks.length;
  }

  /// Tracks for [batch], with tags when the reader answers in time.
  Future<List<Track>> _tracksOf(List<String> batch) async {
    final tags = await _readTags(batch);
    return [
      for (var i = 0; i < batch.length; i++)
        if (tags != null && i < tags.length && tags[i].error == null)
          _trackFrom(batch[i], tags[i])
        else
          Track.fromPath(batch[i]),
    ];
  }

  Track _trackFrom(String path, TrackTags tags) {
    final fallback = Track.fromPath(path);
    final title = tags.title?.trim();
    final artist = tags.artist?.trim();
    final ms = tags.durationMs;
    return Track(
      uri: path,
      title: title == null || title.isEmpty ? fallback.title : title,
      artist: artist == null || artist.isEmpty ? null : artist,
      duration: ms == null ? null : Duration(milliseconds: ms.toInt()),
    );
  }

  /// Tags for [batch] in the same order, or `null` when they cannot be had
  /// (reader stuck, failed or too slow); the files then play by name.
  Future<List<TrackTags>?> _readTags(List<String> batch) async {
    if (_readerStuck) return null;
    final Future<List<TrackTags>> call;
    try {
      call = _ref.read(tagReaderProvider).readBatch(batch);
    } on Object catch (error, stack) {
      _log.warning('Tag reader unavailable', error, stack);
      return null;
    }
    try {
      return await call.timeout(tagTimeout);
    } on TimeoutException {
      _log.warning('Reading tags took over $tagTimeout; using file names');
      _readerStuck = true;
      unawaited(
        call.then<void>(
          (_) => _readerStuck = false,
          onError: (Object _) => _readerStuck = false,
        ),
      );
      return null;
    } on Object catch (error, stack) {
      _log.warning('Reading tags failed; using file names', error, stack);
      return null;
    }
  }
}
