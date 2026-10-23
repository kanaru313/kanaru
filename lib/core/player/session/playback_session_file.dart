import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../../settings/settings_file.dart';
import 'playback_session.dart';
import '../track.dart';
import 'playback_session_codec.dart';
import 'playback_session_off_thread.dart';

final _log = Logger('session');

/// `playback-session.json` next to [settings], or `null` without a settings
/// file (tests, or no config directory): the session then lives in memory.
/// The settings path is not resolved through symlinks, so a `settings.json`
/// linked from dotfiles still keeps the session in the config directory.
///
/// [coverDirectory] is the folder of the cover thumbnails; see
/// [PlaybackSessionFile.coverDirectory].
PlaybackSessionFile? playbackSessionFileFor(
  SettingsFile? settings, {
  String? coverDirectory,
}) {
  if (settings == null) return null;
  return PlaybackSessionFile(
    '${File(settings.path).parent.path}/playback-session.json',
    coverDirectory: coverDirectory,
  );
}

/// Reads and writes the playback session.
///
/// Writes are atomic: the JSON goes to `<path>.<pid>.tmp` and is renamed over
/// the file. Encoding and writing run on another isolate
/// (`writePlaybackSessionOffThread`), and the parts that grow with the queue
/// (tracks, order, unshuffled order) are encoded only when their list
/// changed since the last successful write: a save every few seconds while
/// playing re-encodes only the position, volume and the like. The directory entry is not synced, so a power loss right after
/// a write may bring back the session before it, which is fine for state
/// that is rewritten every few seconds anyway.
///
/// The file becomes read-only for the session when overwriting it could lose
/// something: it could not be read, or a newer Kanaru wrote it.
class PlaybackSessionFile {
  PlaybackSessionFile(this.path, {this.coverDirectory});

  final String path;

  /// Folder of the cover thumbnails. Tracks whose art is in it are saved by
  /// cover key and get the path back from the key on load. `null`: art is
  /// saved and read as it is, and a saved key has no art.
  final String? coverDirectory;

  bool _readOnly = false;
  bool _loaded = false;
  PlaybackSession? _latest;

  /// Snapshot waiting for the write in flight to finish; only the newest
  /// one is kept.
  PlaybackSession? _queued;
  Future<bool>? _writing;

  /// JSON text of the heavy parts last written, and the lists they were
  /// encoded from. Queue lists are never changed in place (every edit makes
  /// a new list), so the same list object means the same text.
  List<Track>? _tracksSource;
  String? _tracksJson;
  List<int>? _orderSource;
  String? _orderJson;
  List<int>? _unshuffledSource;
  String? _unshuffledJson;

  /// Whether [save] skips the disk for the rest of the run.
  bool get readOnly => _readOnly;

  /// The last session loaded or saved, newest first in memory: a player that
  /// is rebuilt restores what the old one saved last, even while that write
  /// is still on its way to disk.
  PlaybackSession? get latest => _latest;

  /// The stored session, or `null` when there is none worth restoring.
  /// Reads the disk the first time only. Never throws: it runs while the
  /// player is built, before the first frame.
  ///
  /// A file that is not a valid session is renamed to `*.invalid`, so it can
  /// still be looked at.
  PlaybackSession? load() {
    if (_loaded) return _latest;
    _loaded = true;
    try {
      if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
        return null;
      }
      final bytes = File(path).readAsBytesSync();
      final Map<String, Object?> json;
      try {
        final decoded = jsonDecode(_withoutBom(utf8.decode(bytes)));
        if (decoded is! Map<String, Object?>) {
          throw const FormatException('not an object');
        }
        json = decoded;
      } on FormatException {
        _quarantine();
        return null;
      }
      final version = playbackSessionVersionOf(json);
      if (version != null && version > playbackSessionVersion) {
        _readOnly = true;
        _log.warning(
          'playback-session.json has version $version, newer than '
          '$playbackSessionVersion: not restoring or saving it this run',
        );
        return null;
      }
      try {
        if (version == null) throw const FormatException('version');
        return _latest = decodePlaybackSession(
          json,
          coverDirectory: coverDirectory,
        );
      } on FormatException {
        _quarantine();
        return null;
      }
    } catch (error) {
      _readOnly = true;
      _log.warning(
        'Could not read playback-session.json (${_describe(error)}): '
        'starting empty, not saving the session this run',
      );
      return null;
    }
  }

  /// Writes [session]. Writes run one at a time; snapshots saved while one
  /// is in flight collapse into the newest. Never throws; returns `false`
  /// when the write failed. A read-only file skips the disk and returns
  /// `true`: [readOnly] reports that case.
  Future<bool> save(PlaybackSession session) {
    _loaded = true;
    _latest = session;
    if (_readOnly) return Future.value(true);
    _queued = session;
    return _writing ??= _drain();
  }

  /// Completes once every snapshot saved so far is on disk (or failed).
  Future<void> flush() async {
    await _writing;
  }

  Future<bool> _drain() async {
    var saved = true;
    try {
      for (var next = _queued; next != null; next = _queued) {
        _queued = null;
        saved = await _write(next);
      }
    } finally {
      _writing = null;
    }
    return saved;
  }

  Future<bool> _write(PlaybackSession session) async {
    final tracksJson = identical(session.tracks, _tracksSource)
        ? _tracksJson
        : null;
    final orderJson = identical(session.order, _orderSource)
        ? _orderJson
        : null;
    final unshuffledJson = identical(session.unshuffledOrder, _unshuffledSource)
        ? _unshuffledJson
        : null;
    try {
      final encoded = await writePlaybackSessionOffThread(
        path: path,
        light: encodePlaybackSessionLight(session),
        tracksJson: tracksJson,
        tracks: tracksJson == null ? session.tracks : null,
        coverDirectory: coverDirectory,
        orderJson: orderJson,
        order: orderJson == null ? session.order : null,
        unshuffledJson: unshuffledJson,
        encodeUnshuffled: unshuffledJson == null,
        unshuffledOrder: session.unshuffledOrder,
      );
      if (encoded.tracks case final text?) {
        _tracksSource = session.tracks;
        _tracksJson = text;
      }
      if (encoded.order case final text?) {
        _orderSource = session.order;
        _orderJson = text;
      }
      if (encoded.unshuffledOrder case final text?) {
        _unshuffledSource = session.unshuffledOrder;
        _unshuffledJson = text;
      }
      return true;
    } catch (error) {
      _log.warning(
        'Could not save playback-session.json (${_describe(error)})',
      );
      try {
        await File(playbackSessionTemporaryPath(path)).delete();
      } on FileSystemException {
        // Never created, or already renamed.
      }
      return false;
    }
  }

  void _quarantine() {
    try {
      File(path).renameSync('$path.invalid');
      _log.warning(
        'playback-session.json is not a valid session: moved it to '
        'playback-session.json.invalid and starting empty',
      );
    } on FileSystemException catch (error) {
      _readOnly = true;
      _log.warning(
        'playback-session.json is not a valid session and could not be moved '
        'aside (${_describe(error)}): starting empty',
      );
    }
  }
}

/// The error without the file's contents (a [FormatException] message
/// quotes them) and without the full path.
String _describe(Object error) => switch (error) {
  FileSystemException(:final osError?) => osError.message,
  _ => error.runtimeType.toString(),
};

String _withoutBom(String text) =>
    text.startsWith('﻿') ? text.substring(1) : text;
