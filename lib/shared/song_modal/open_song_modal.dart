import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../l10n/l10n.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_actions_menu.dart';
import '../widgets/track_menu_lookups.dart';
import 'song_modal_actions_page.dart';
import 'song_modal_session.dart';

/// Opens the song modal for [song]. Returns at once: everything the actions
/// need from [context] (router, messenger, texts) is captured here, before the
/// modal opens, and the favorite and links load inside it.
///
/// Queue actions go to [onQueueAction]; the rest is carried out by a
/// `TrackMenuRunner` after the modal has closed. [showAlbum] false
/// leaves out Go to album, on the page of the song's own album. [extraActions] are the actions of the screen the song
/// is listed on; they come first. [viaKeyboard] focuses the first row.
void openSongModal(
  BuildContext context,
  WidgetRef ref, {
  required TrackListItem song,
  required ValueChanged<QueueAction> onQueueAction,
  bool showAlbum = true,
  bool viaKeyboard = false,
  List<ContextModalAction> extraActions = const [],
}) {
  final session = SongModalSession(
    song: song,
    runner: TrackMenuRunner(ref, context),
    onQueueAction: onQueueAction,
    lyricsTarget: menuLyricsTarget(ref, song),
    showAlbum: showAlbum,
    extraActions: extraActions,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: songModalActionsPage(session),
      semanticLabel: context.l10n.songModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
