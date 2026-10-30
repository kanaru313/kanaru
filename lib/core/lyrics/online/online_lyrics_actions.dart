import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../lyrics_translation/lyrics_content_hash.dart';
import '../lyrics.dart';
import '../playing_local_lyrics_provider.dart';
import 'candidate_content_hash.dart';
import 'lyrics_choice.dart';
import 'lyrics_provider.dart';
import 'lyrics_target.dart';
import 'online_lyrics_lookups.dart';
import 'online_lyrics_reject_action.dart';
import 'online_lyrics_save_action.dart';
import 'online_lyrics_streams.dart';
import 'playing_lyrics_status.dart';

export 'online_lyrics_save_action.dart'
    show LyricsChoiceKept, LyricsSaveOutcome;

/// What the user can do about a song's lyrics source. Works from any
/// `ProviderContainer` (a menu that outlives its widget has no live
/// `WidgetRef`); every request goes through [OnlineLyricsLookups.start], so
/// the consent check in core applies. Without a library each action does
/// nothing. Only [save] writes a file.
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

  /// Sets which lyrics the song shows.
  ///
  /// * `auto` forgets the choice and the pick (the row goes);
  /// * `local` and `off` keep a stored pick, so choosing `online` again
  ///   brings it back;
  /// * `online` needs a stored pick and does nothing without one.
  ///
  /// Choosing what is already stored writes nothing. After `auto` or `local`,
  /// changed or not, the song's own lyrics are read again, so a `.lrc` that
  /// appeared since is found. `online` and `off` of the stored mode touch
  /// nothing, so no new `Lyrics` instance is made.
  Future<void> choose(LyricsTarget target, LyricsChoice choice) async {
    final db = _db;
    if (db == null) return;
    final pin = await db.watchLyricsPin(target.trackKey).first;
    final same = choice == LyricsChoice.auto
        ? pin == null
        : pin != null && parseLyricsChoice(pin.mode) == choice;
    if (same) {
      // Nothing to write, but picking the checked item is a way to ask for
      // the song's own lyrics to be read again.
      _refreshLocal(choice);
      return;
    }
    switch (choice) {
      case LyricsChoice.auto:
        await db.removeLyricsPin(target.trackKey);
      case LyricsChoice.online:
        if (pin?.remoteId == null) return;
        await db.setLyricsChoice(target.trackKey, 'online', _now);
      case LyricsChoice.local || LyricsChoice.off:
        await db.setLyricsChoice(
          target.trackKey,
          lyricsChoiceMode(choice)!,
          _now,
        );
    }
    if (_ref.mounted) _refreshLocal(choice);
  }

  void _refreshLocal(LyricsChoice choice) {
    if (choice == LyricsChoice.auto || choice == LyricsChoice.local) {
      _ref.invalidate(playingLocalLyricsProvider);
    }
  }

  /// "Keep this one": makes the automatic match [origin] the song's pick.
  /// Does nothing when its text is gone from the cache (it changed since the
  /// menu opened).
  Future<void> keep(LyricsTarget target, OnlineLyricsOrigin origin) async {
    final db = _db;
    if (db == null) return;
    final stored = await db.storedOnlineLyricsText(
      trackKey: target.trackKey,
      cacheKey: target.cacheKey,
      providerId: origin.providerId,
      remoteId: origin.remoteId,
    );
    if (stored == null) return;
    final lyrics = parseStoredLyrics(
      synced: stored.synced,
      plain: stored.plain,
    );
    await db.pickOnlineLyrics(
      LyricsPinsCompanion.insert(
        trackKey: target.trackKey,
        pinnedAt: _now,
        providerId: Value(origin.providerId),
        remoteId: Value(origin.remoteId),
        syncedText: Value(stored.synced),
        plainText: Value(stored.plain),
        instrumental: Value(stored.instrumental),
        remoteDurationMs: Value(stored.remoteDurationMs),
      ),
      cacheKey: target.cacheKey,
      providerId: origin.providerId,
      remoteId: origin.remoteId,
      contentHash: lyrics == null ? null : lyricsContentHashOf(lyrics),
    );
  }

  /// "Not these lyrics": see [rejectOnlineLyrics].
  Future<void> reject(
    LyricsTarget target,
    OnlineLyricsOrigin origin,
    Lyrics shown,
  ) => rejectOnlineLyrics(_ref, target, origin, shown);

  /// Makes [candidate] (it must carry its body) the song's lyrics. A
  /// rejected match picked again is no longer rejected. Writes to the
  /// database only, never a file.
  Future<void> pick(LyricsTarget target, LyricsCandidate candidate) async {
    final body = candidate.body;
    if (body == null) {
      throw ArgumentError.value(candidate, 'candidate', 'has no lyrics body');
    }
    final db = _db;
    if (db == null) return;
    await db.pickOnlineLyrics(
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
      cacheKey: target.cacheKey,
      providerId: candidate.providerId,
      remoteId: candidate.remoteId,
      contentHash: candidateContentHash(candidate),
    );
  }

  final _saving = <String>{};

  /// A save of the song with [trackKey] is running.
  bool isSaving(String trackKey) => _saving.contains(trackKey);

  /// "Save lyrics": writes the stored text of [origin] as the song's `.lrc`
  /// (see [saveOnlineLyrics]). With [replace] an existing file goes to the
  /// trash first; without it an existing file is left alone. A second save
  /// of the same song while one runs is ignored and answers `result: null`.
  Future<LyricsSaveOutcome> save(
    LyricsTarget target,
    OnlineLyricsOrigin origin, {
    bool replace = false,
  }) async {
    if (!_saving.add(target.trackKey)) return (result: null, kept: null);
    try {
      return await saveOnlineLyrics(_ref, target, origin, replace: replace);
    } finally {
      _saving.remove(target.trackKey);
    }
  }
}

final onlineLyricsActionsProvider = Provider<OnlineLyricsActions>(
  OnlineLyricsActions.new,
);
