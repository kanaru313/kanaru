import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/playing_track_art.dart' show localPathOf;
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'enqueue_chain.dart';
import 'queue_host.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';

/// [enqueueTracks] for tracks already at hand, naming them [label].
///
/// A current [QueueHost] (the song modal runs its queue actions with one)
/// overrides [ref] and [context]: the action then uses what the host captured
/// before the modal opened, so it still works after the row is gone. This function and
/// `enqueueFromDatabase` honor the host; the other enqueue functions use their
/// own [ref] and [context].
///
/// [excludePlaylistId] hides the playlist the tracks come from in the
/// "Add to playlist" picker.
void enqueueLoaded(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  List<Track> tracks,
  String label, {
  int? excludePlaylistId,
}) {
  // A song modal runs its queue actions with a host captured before it
  // opened, so the row that opened it may be gone by now.
  final host = QueueHost.current;
  if (host != null) {
    host.enqueueLoaded(
      action,
      tracks,
      label,
      excludePlaylistId: excludePlaylistId,
    );
    return;
  }
  // The menu closes later than it opened: its page may be gone by then.
  if (!context.mounted) return;
  if (action == QueueAction.addToPlaylist) {
    // Library tracks carry their file path as uri.
    unawaited(
      addTracksToPlaylist(
        ref,
        context,
        () async => [for (final t in tracks) ?localPathOf(t.uri)],
        label,
        excludePlaylistId: excludePlaylistId,
        viaKeyboard: QueueHost.currentViaKeyboard,
      ),
    );
    return;
  }
  unawaited(
    enqueueTracks(
      ref,
      ScaffoldMessenger.of(context),
      context.l10n,
      action,
      () async => tracks,
      label,
    ),
  );
}
