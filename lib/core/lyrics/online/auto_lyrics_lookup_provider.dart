import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lyrics_target.dart';
import 'online_lyrics_backoff.dart';
import 'online_lyrics_lookups.dart';

/// Waits the debounce, then starts the automatic lookup of [target]. Watched
/// by the resolution for as long as that lookup is wanted: a song skipped
/// within the debounce disposes it first and nothing is sent. The request
/// itself runs in the keepAlive lookups notifier, which also dedupes it;
/// disposal during a wait before a busy answer is sent again stops that
/// lookup, unless another caller has joined it.
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
      await ref
          .read(onlineLyricsLookupsProvider.notifier)
          .start(target, auto: true, abandoned: () => abandoned);
    }, retry: (_, _) => null);
