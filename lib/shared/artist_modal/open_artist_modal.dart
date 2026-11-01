import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../artist_summaries.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_actions_menu.dart';
import 'artist_modal_actions_page.dart';
import 'artist_modal_session.dart';

/// Opens the artist modal for [artist]. Returns at once: everything the
/// actions need from [context] (router, messenger, texts) is captured here,
/// before the modal opens, and the albums and folders load inside it. The
/// counts in the header come from [artist] as it is now.
///
/// Queue actions go to [onQueueAction], run with the `QueueHost` built from
/// what the runner captured here so they work after the row is gone; the
/// rest is carried out after the modal has closed. [showArtist] false leaves
/// out Go to artist, on the page of the artist itself. [viaKeyboard] focuses
/// the first row.
void openArtistModal(
  BuildContext context,
  WidgetRef ref, {
  required ArtistSummary artist,
  required ValueChanged<QueueAction> onQueueAction,
  bool showArtist = true,
  bool viaKeyboard = false,
}) {
  final session = ArtistModalSession(
    artist: artist,
    runner: TrackMenuRunner(ref, context),
    onQueueAction: onQueueAction,
    showArtist: showArtist,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: artistModalActionsPage(session),
      semanticLabel: context.l10n.artistModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
