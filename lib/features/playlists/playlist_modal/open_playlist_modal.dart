import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../m3u_file_pickers.dart';
import 'playlist_modal_actions_page.dart';
import 'playlist_modal_session.dart';

/// Opens the playlist modal for [playlist]. Returns at once: everything the
/// actions need from [context] (router, messenger, navigator, texts, the save
/// picker) is captured here, before the modal opens, and the head and counts
/// load inside it. [coverKeys] and [playlist] are shown until the head
/// arrives.
///
/// [showGoTo] false leaves out Go to playlist, on the page of the playlist
/// itself. [beforeRead] completes when the opener has no write in flight; it
/// is awaited before any action reads the entries. [viaKeyboard] focuses the
/// first row.
void openPlaylistModal(
  BuildContext context,
  WidgetRef ref, {
  required PlaylistSummary playlist,
  required List<String> coverKeys,
  bool showGoTo = true,
  bool viaKeyboard = false,
  Future<void> Function()? beforeRead,
}) {
  final session = PlaylistModalSession(
    playlist: playlist,
    coverKeys: coverKeys,
    runner: TrackMenuRunner(ref, context),
    db: ref.read(libraryDatabaseProvider),
    l10n: context.l10n,
    openerMessenger: ScaffoldMessenger.maybeOf(context),
    rootNavigator: Navigator.maybeOf(context, rootNavigator: true),
    router: GoRouter.maybeOf(context),
    save: ref.read(m3uSavePickerProvider),
    showGoTo: showGoTo,
    beforeRead: beforeRead,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: playlistModalActionsPage(session),
      semanticLabel: context.l10n.playlistModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
