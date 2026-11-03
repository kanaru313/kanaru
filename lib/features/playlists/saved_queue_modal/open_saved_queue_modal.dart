import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import 'saved_queue_modal_pages.dart';
import 'saved_queue_modal_session.dart';

/// Opens the modal of the saved queue [playlist] (any name; it is shown as
/// the time it was saved). Returns at once: everything the actions need from
/// [context] is captured here, before the modal opens, and the head and
/// counts load inside it. [coverKeys] and [playlist] are shown until the head
/// arrives.
///
/// [showGoTo] false leaves out Go to queue, on the page of the queue itself.
/// [beforeRead] completes when the opener has no write in flight; it is
/// awaited before any action reads or writes the entries. [viaKeyboard]
/// focuses the first row.
void openSavedQueueModal(
  BuildContext context,
  WidgetRef ref, {
  required PlaylistSummary playlist,
  required List<String> coverKeys,
  bool showGoTo = true,
  bool viaKeyboard = false,
  Future<void> Function()? beforeRead,
}) {
  final session = SavedQueueModalSession(
    playlist: playlist,
    coverKeys: coverKeys,
    runner: TrackMenuRunner(ref, context),
    showGoTo: showGoTo,
    beforeRead: beforeRead,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: savedQueueModalActionsPage(session),
      semanticLabel: context.l10n.queueModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
