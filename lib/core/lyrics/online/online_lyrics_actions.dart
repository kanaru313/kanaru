import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../settings/settings_provider.dart';
import 'lrc_sidecar_writer.dart';
import 'lyrics_provider.dart';
import 'lyrics_target.dart';
import 'online_lyrics_lookups.dart';
import 'online_lyrics_streams.dart';
import 'playing_lyrics_status.dart';

/// What the user can do about a song's online lyrics. Works from any
/// `ProviderContainer` (a menu that outlives its widget has no live
/// `WidgetRef`); every request goes through [OnlineLyricsLookups.start], so
/// the consent check in core applies. Without a library each action does
/// nothing.
class OnlineLyricsActions {
  OnlineLyricsActions(this._ref);

  final Ref _ref;

  LibraryDatabase? get _db => _ref.read(libraryDatabaseProvider);
  int get _now => _ref.read(onlineLyricsClockProvider)().millisecondsSinceEpoch;

  Future<void> _lookUp(LyricsTarget target) => _ref
      .read(onlineLyricsLookupsProvider.notifier)
      .start(target, auto: false);

  /// Looks the song up again after a failure, ending the session pause.
  Future<void> retry(LyricsTarget target) {
    _ref.read(onlineLyricsBackoffProvider.notifier).clear();
    return _lookUp(target);
  }

  /// Forgets the pick and every cached answer for the song's metadata and
  /// looks it up again. Matches the user rejected stay excluded.
  Future<void> searchAgain(LyricsTarget target) async {
    final db = _db;
    if (db == null) return;
    _ref.read(onlineLyricsBackoffProvider.notifier).clear();
    await db.removeLyricsPin(target.trackKey);
    await db.deleteOnlineLyrics(target.cacheKey);
    if (!_ref.mounted) return;
    await _lookUp(target);
  }

  /// "Not these lyrics": remembers [origin]'s match as rejected for the
  /// song's metadata, drops its cached row and shows no online lyrics for the
  /// song until the user picks.
  Future<void> skip(LyricsTarget target, OnlineLyricsOrigin origin) async {
    await _db?.rejectOnlineLyrics(
      cacheKey: target.cacheKey,
      providerId: origin.providerId,
      remoteId: origin.remoteId,
      trackKey: target.trackKey,
      now: _now,
    );
  }

  /// Pins [candidate] (it must carry its body) as the song's lyrics, then
  /// writes the `.lrc` file when the setting is on and the song is a local
  /// file. Returns the writer's answer, `null` when no write was tried. The
  /// pin stands whatever the write does.
  Future<LrcWriteResult?> pick(
    LyricsTarget target,
    LyricsCandidate candidate,
  ) async {
    final body = candidate.body;
    if (body == null) {
      throw ArgumentError.value(candidate, 'candidate', 'has no lyrics body');
    }
    final db = _db;
    if (db == null) return null;
    await db.pinLyrics(
      LyricsPinsCompanion.insert(
        trackKey: target.trackKey,
        pinnedAt: _now,
        providerId: Value(candidate.providerId),
        remoteId: Value(candidate.remoteId),
        syncedText: Value(body.syncedLrc),
        plainText: Value(body.plain),
        instrumental: Value(body.instrumental),
        remoteDurationMs: Value(candidate.duration?.inMilliseconds),
      ),
    );
    final path = target.path;
    if (!_ref.mounted ||
        path == null ||
        !_ref.read(settingsProvider).onlineLyrics.writeLrc) {
      return null;
    }
    return _ref.read(lrcSidecarWriterProvider).write(path, body);
  }

  /// Removes the song's pick or skip, so local lyrics, the cache and
  /// automatic lookup apply again.
  Future<void> unpin(LyricsTarget target) async {
    await _db?.removeLyricsPin(target.trackKey);
  }
}

final onlineLyricsActionsProvider = Provider<OnlineLyricsActions>(
  OnlineLyricsActions.new,
);
