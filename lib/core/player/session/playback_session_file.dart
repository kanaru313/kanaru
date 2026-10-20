import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../../settings/settings_file.dart';
import 'playback_session.dart';
import 'playback_session_codec.dart';

final _log = Logger('session');

/// `playback-session.json` next to [settings], or `null` without a settings
/// file (tests, or no config directory): the session then lives in memory.
/// The settings path is not resolved through symlinks, so a `settings.json`
/// linked from dotfiles still keeps the session in the config directory.
PlaybackSessionFile? playbackSessionFileFor(SettingsFile? settings) {
  if (settings == null) return null;
  return PlaybackSessionFile(
    '${File(settings.path).parent.path}/playback-session.json',
  );
}

/// Reads and writes the playback session.
///
/// Writes are atomic: the JSON goes to `<path>.<pid>.tmp` and is renamed over
/// the file. The directory entry is not synced, so a power loss right after
/// a write may bring back the session before it, which is fine for state
/// that is rewritten every few seconds anyway.
///
/// The file becomes read-only for the session when overwriting it could lose
/// something: it could not be read, or a newer Kanaru wrote it.
class PlaybackSessionFile {
  PlaybackSessionFile(this.path);

  final String path;

  bool _readOnly = false;
  bool _loaded = false;
  PlaybackSession? _latest;

  /// Snapshot waiting for the write in flight to finish; only the newest
  /// one is kept.
  PlaybackSession? _queued;
  Future<bool>? _writing;

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
        return _latest = decodePlaybackSession(json);
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
    File? temporary;
    try {
      await File(path).parent.create(recursive: true);
      temporary = File('$path.$pid.tmp');
      await temporary.writeAsString(
        jsonEncode(encodePlaybackSession(session)),
        flush: true,
      );
      await temporary.rename(path);
      return true;
    } catch (error) {
      _log.warning(
        'Could not save playback-session.json (${_describe(error)})',
      );
      try {
        await temporary?.delete();
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
