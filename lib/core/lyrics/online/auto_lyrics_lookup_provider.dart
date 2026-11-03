import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../settings/settings_provider.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';
import 'online_lyrics_backoff.dart';
import 'online_lyrics_entries.dart';
import 'online_lyrics_lookups.dart';

/// Waits the debounce, then starts the automatic lookup of [target]. Watched
/// by the resolution for as long as that lookup is wanted: a song skipped
/// within the debounce disposes it first and nothing is sent. The request
/// itself runs in the keepAlive lookups notifier, which also dedupes it;
/// disposal during a wait before a busy answer is sent again stops that
/// lookup, unless another caller has joined it.
///
/// A lookup that ends with an enabled source that has no stored row (its
/// failure was dropped by Settings "Clear", say) and no usable lyrics leaves
/// the song neither answered nor failed, so the provider restarts itself.
/// Any stored row, found or not found, stale or not, counts as an answer, so
/// there is no request loop. A source the lookup skipped without a failure (a
/// busy plugin runtime) is asked again only after
/// [onlineLyricsSkipRetryProvider], or when the song is shown again; the
/// pending retry is dropped with the provider.
final autoLyricsLookupProvider = FutureProvider.autoDispose
    .family<void, LyricsTarget>((ref, target) async {
      final waited = Completer<void>();
      final timer = Timer(
        ref.read(onlineLyricsDebounceProvider),
        waited.complete,
      );
      var abandoned = false;
      ref.onDispose(() {
        abandoned = true;
        timer.cancel();
        if (!waited.isCompleted) waited.complete();
      });
      await waited.future;
      if (!ref.mounted) return;
      final lookups = ref.read(onlineLyricsLookupsProvider.notifier);
      await lookups.start(target, auto: true, abandoned: () => abandoned);
      if (!ref.mounted || abandoned) return;
      if (ref.read(onlineLyricsLookupsProvider).containsKey(target.cacheKey)) {
        return;
      }
      // Only a lookup that stored no answer needs another go. The watching
      // resolution also gates on the setting and the consent; the checks
      // here keep a lookup that never sends anything from re-arming.
      final db = ref.read(libraryDatabaseProvider);
      if (db == null || !target.isAutoSearchable) return;
      final prefs = ref.read(settingsProvider).onlineLyrics;
      if (!prefs.autoAllowed || ref.read(lyricsProvidersProvider).isEmpty) {
        return;
      }
      final stored = await db.watchOnlineLyrics(target.cacheKey).first;
      if (!ref.mounted || abandoned) return;
      final hasLyrics = stored.any((row) {
        final entry = OnlineLyricsEntry.fromRow(row, row.lookupStatus!);
        return entry.status == OnlineLyricsStatus.found &&
            (entry.lyrics != null || entry.instrumental);
      });
      // Only a source with no row at all was dropped; a stale or unparsable
      // row is a stored answer and must not restart the lookup.
      // A source skipped for an empty required setting is not unanswered:
      // asking it again changes nothing until the lookup runs again (a track
      // change, or Now Playing shown again).
      final blocked = lookups.blockedByConfig(target.cacheKey);
      final unanswered = ref
          .read(lyricsProvidersProvider)
          .any(
            (r) =>
                !blocked.contains(r.id) &&
                !stored.any((row) => row.providerId == r.id),
          );
      if (hasLyrics || !unanswered) return;
      // With a blocked source around, an immediate re-run would ask it (and
      // report it) again at every debounce while another source is paused:
      // wait for the timer instead.
      if (blocked.isEmpty && !lookups.leftSourceUnasked(target.cacheKey)) {
        ref.invalidateSelf();
        return;
      }
      final retry = Timer(ref.read(onlineLyricsSkipRetryProvider), () {
        if (ref.mounted && !abandoned) ref.invalidateSelf();
      });
      ref.onDispose(retry.cancel);
    }, retry: (_, _) => null);
