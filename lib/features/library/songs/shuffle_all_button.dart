import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_song_paging.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../play_tracks.dart';
import 'songs_list_provider.dart';

final _log = Logger('library');

/// "Shuffle all" for the title row of Songs: plays the whole library with
/// shuffle on, from a random song. Disabled until the song list has loaded
/// and while it is empty. On a compact header ([PageScaffold.compactActionsOf])
/// only the icon is shown, with the label as its tooltip.
class ShuffleAllButton extends ConsumerStatefulWidget {
  const ShuffleAllButton({super.key});

  @override
  ConsumerState<ShuffleAllButton> createState() => _ShuffleAllButtonState();
}

class _ShuffleAllButtonState extends ConsumerState<ShuffleAllButton> {
  /// The queue is being read; ignores a second tap meanwhile.
  bool _busy = false;

  /// Reads the library once in the sort of the Songs list and opens it
  /// shuffled. The list's first id only anchors the read, whose start index
  /// is not needed: the player picks a random one.
  Future<void> _shuffleAll() async {
    if (_busy) return;
    final songs = ref.read(songIdsProvider).value;
    final db = ref.read(libraryDatabaseProvider);
    final anyId = songs?.ids.firstOrNull;
    if (songs == null || db == null || anyId == null) return;
    final covers = ref.read(coverCacheDirectoryProvider);
    final player = ref.read(playerServiceProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final (items, _) = await db.songQueueFrom(
        anyId,
        order: songs.order,
        descending: songs.descending,
      );
      // Not guarded by `mounted`: leaving the page does not cancel the tap.
      unawaited(
        player.openShuffled([
          for (final s in items)
            trackFromItem(
              path: s.path,
              title: s.title,
              artist: s.artist,
              durationMs: s.durationMs,
              artPath: coverPath(covers, s.coverKey),
            ),
        ]),
      );
    } catch (error, stackTrace) {
      _log.severe('Reading the play queue failed', error, stackTrace);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryUnexpectedError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = ref.watch(
      songIdsProvider.select((s) => s.value?.ids.isNotEmpty ?? false),
    );
    final onPressed = ready && !_busy ? _shuffleAll : null;
    if (PageScaffold.compactActionsOf(context)) {
      return IconButton(
        tooltip: l10n.songsShuffleAll,
        icon: const Icon(Icons.shuffle_rounded),
        onPressed: onPressed,
      );
    }
    return TextButton.icon(
      icon: const Icon(Icons.shuffle_rounded),
      label: Text(l10n.songsShuffleAll),
      onPressed: onPressed,
    );
  }
}
