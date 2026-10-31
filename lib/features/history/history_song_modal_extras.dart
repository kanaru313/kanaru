import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/song_modal/song_modal_data.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/context_modal/context_modal_route.dart';
import 'history_delete_undo.dart';
import 'history_plays_version.dart';

/// What the song modal of a played song adds: Song history (opens
/// `location(path)`) and, for a play of the journal ([playId] set), a red
/// Remove from history with an Undo snackbar. [headerNote] is the quiet line
/// under the album, if any.
///
/// Call it when the modal opens (it is a `SongModalExtrasBuilder` body): the
/// router, database, messenger, texts, version notifier and undo service are
/// read from [context] and [ref] here, so the actions still work after the
/// row is gone. [playId] is the play the modal was opened on; the list may
/// move before Remove is tapped, and still that play goes.
SongModalExtras historyPlayExtras({
  required BuildContext context,
  required WidgetRef ref,
  required String path,
  required String Function(String path) location,
  int? playId,
  String? headerNote,
}) {
  final l10n = context.l10n;
  final router = GoRouter.of(context);
  final db = ref.read(libraryDatabaseProvider);
  final messenger = ScaffoldMessenger.of(context);
  final version = ref.read(historyPlaysVersionProvider.notifier);
  final undo = ref.read(historyDeleteUndoProvider);
  return SongModalExtras(
    headerNote: headerNote,
    actions: [
      ContextModalAction(
        id: 'song-history',
        icon: AppIcons.history,
        label: l10n.historyShowTrackHistory,
        onTap: songModalCloseThen(() => router.go(location(path))),
      ),
      if (playId != null && db != null)
        ContextModalAction(
          id: 'remove-from-history',
          icon: AppIcons.deleteOutline,
          label: l10n.historyDeletePlay,
          destructive: true,
          onTap: songModalCloseThen(
            () => unawaited(
              undo.delete(
                db: db,
                messenger: messenger,
                l10n: l10n,
                version: version,
                playId: playId,
              ),
            ),
          ),
        ),
    ],
  );
}
