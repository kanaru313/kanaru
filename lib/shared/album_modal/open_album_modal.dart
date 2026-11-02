import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/queue_actions_menu.dart';
import 'album_modal_actions_page.dart';
import 'album_modal_session.dart';

/// Opens the album modal for [album]. Returns at once: everything the actions
/// need from [context] (router, messenger, texts) is captured here, before
/// the modal opens, and the artists and folders load inside it.
///
/// Queue actions go to [onQueueAction], run with the `QueueHost` built from
/// what the runner captured here so they work after the tile is gone; the
/// rest is carried out after the modal has closed. [showAlbum] false leaves
/// out Go to album, on the page of the album itself. [pageArtistKey] is the
/// artist whose page lists the album, left out of Go to artist (null
/// elsewhere). [viaKeyboard] focuses the first row.
void openAlbumModal(
  BuildContext context,
  WidgetRef ref, {
  required AlbumTileData album,
  required ValueChanged<QueueAction> onQueueAction,
  bool showAlbum = true,
  String? pageArtistKey,
  bool viaKeyboard = false,
}) {
  final session = AlbumModalSession(
    album: album,
    runner: TrackMenuRunner(ref, context),
    onQueueAction: onQueueAction,
    showAlbum: showAlbum,
    pageArtistKey: pageArtistKey,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: albumModalActionsPage(session),
      semanticLabel: context.l10n.albumModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
