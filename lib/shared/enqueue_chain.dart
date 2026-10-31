import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/player_service.dart';
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'widgets/app_snack_bar.dart';
import 'widgets/queue_actions_menu.dart';

final _log = Logger('library');

/// A queue snackbar shown or waiting behind other messages.
class _PendingMessage {
  _PendingMessage(this.text, this.messenger);

  /// The text on the snackbar; changing it updates the snackbar in place.
  final ValueNotifier<String> text;
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;

  /// The snackbar has finished appearing, which is when its time on screen
  /// starts running: from then on a new text would not get a time of its own.
  bool visible = false;
}

/// Tail of the library-level enqueues: each one waits for the one before, so
/// two quick menu picks land in the queue in click order even when their
/// database reads finish in another order. Also holds the queue message still
/// on its way to the screen, so a newer one replaces it instead of piling up.
class _EnqueueChain {
  Future<void> tail = Future.value();

  /// The queue snackbar not gone yet. Null once it is.
  _PendingMessage? pending;
}

final _enqueueChainProvider = Provider<_EnqueueChain>((ref) => _EnqueueChain());

/// Resolves once every library-level enqueue started so far has finished.
/// A caller about to act on the queue awaits it first, so an earlier pick
/// still reading from the database is not overtaken by what comes after.
Future<void> pendingQueuePicks(WidgetRef ref) =>
    ref.read(_enqueueChainProvider).tail;

/// Says [text] in a snackbar. While an earlier queue message waits its turn on
/// the same [messenger], its text is replaced instead: only the latest pick is
/// worth reading. One already on screen is closed and the new text gets a
/// snackbar, and so a time on screen, of its own. Other messages (a finished
/// scan) are never touched.
void _showQueueMessage(
  _EnqueueChain chain,
  ScaffoldMessengerState messenger,
  String text,
) {
  final earlier = chain.pending;
  if (earlier != null && identical(earlier.messenger, messenger)) {
    if (!earlier.visible) {
      earlier.text.value = text;
      return;
    }
    chain.pending = null;
    earlier.controller.close();
  }
  final message = _PendingMessage(ValueNotifier(text), messenger);
  message.controller = messenger.showSnackBar(
    SnackBar(
      onVisible: () => message.visible = true,
      content: ValueListenableBuilder<String>(
        valueListenable: message.text,
        builder: (_, value, _) =>
            AppSnackBarContent(kind: AppSnackBarKind.success, title: value),
      ),
    ),
  );
  chain.pending = message;
  unawaited(
    message.controller.closed.then((_) {
      if (identical(chain.pending, message)) chain.pending = null;
      message.text.dispose();
    }),
  );
}

/// Puts the tracks [read] returns behind the playing one ([QueueAction.playNext])
/// or at the end of the queue, then says so in a snackbar naming [label]
/// (or that [label] is playing, when the queue was empty and it started).
/// Runs after every earlier call, whatever happened to them. Everything it
/// needs from the widget tree ([messenger], [l10n]) is passed in, as the
/// caller may be gone by the time the read finishes. [QueueAction.addToPlaylist] is not a queue action:
/// `enqueueLoaded` and `enqueueFromDatabase` handle it, and passing it here
/// throws [ArgumentError].
Future<void> enqueueTracks(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  QueueAction action,
  Future<List<Track>> Function() read,
  String label,
) => _enqueue(
  ref.read(_enqueueChainProvider),
  ref.read(playerServiceProvider.notifier),
  messenger,
  l10n,
  action,
  read,
  label,
);

/// [enqueueTracks] for a caller with no live [WidgetRef]: it reads the queue
/// from [container], which outlives any row.
Future<void> enqueueTracksIn(
  ProviderContainer container,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  QueueAction action,
  Future<List<Track>> Function() read,
  String label,
) => _enqueue(
  container.read(_enqueueChainProvider),
  container.read(playerServiceProvider.notifier),
  messenger,
  l10n,
  action,
  read,
  label,
);

Future<void> _enqueue(
  _EnqueueChain chain,
  PlayerService player,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  QueueAction action,
  Future<List<Track>> Function() read,
  String label,
) {
  if (action == QueueAction.addToPlaylist) {
    throw ArgumentError.value(action, 'action', 'not a queue action');
  }
  Future<void> attempt() async {
    final String text;
    try {
      final tracks = await read();
      // The album or artist vanished in a rescan: nothing to queue.
      if (tracks.isEmpty) return;
      // The guard on entry leaves just these two.
      final next = action == QueueAction.playNext;
      final started = next
          ? await player.playNext(tracks)
          : await player.addToQueue(tracks);
      text = started
          ? l10n.queuePlaying(label)
          : next
          ? l10n.queuePlayingNext(label)
          : l10n.queueAddedToQueue(label);
    } catch (error, stackTrace) {
      _log.severe('Queuing tracks failed', error, stackTrace);
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
      return;
    }
    // The tracks are queued: failing to say so is no queuing failure.
    try {
      _showQueueMessage(chain, messenger, text);
    } catch (error, stackTrace) {
      _log.warning('Showing the queue message failed', error, stackTrace);
    }
  }

  // Reporting the failure can fail too (the messenger may be gone): that must
  // not leave the chain rejected, or no later pick would ever run.
  final run = chain.tail.then((_) => attempt()).catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _log.severe('Reporting a queuing failure failed', error, stackTrace);
  });
  chain.tail = run;
  return run;
}
