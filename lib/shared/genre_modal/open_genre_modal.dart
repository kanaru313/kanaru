import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../genre_summaries.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_actions_menu.dart';
import 'genre_modal_actions_page.dart';
import 'genre_modal_session.dart';

/// Opens the genre modal for [genre]. Returns at once: everything the
/// actions need from [context] (router, messenger, texts) is captured here,
/// before the modal opens, and the albums and folders load inside it. The
/// counts in the header come from [genre] as it is now.
///
/// Queue actions go to [onQueueAction], run with the `QueueHost` built from
/// what the runner captured here so they work after the row is gone; the
/// rest is carried out after the modal has closed. [showGenre] false leaves
/// out Go to genre, on the page of the genre itself. [viaKeyboard] focuses
/// the first row.
void openGenreModal(
  BuildContext context,
  WidgetRef ref, {
  required GenreSummary genre,
  required ValueChanged<QueueAction> onQueueAction,
  bool showGenre = true,
  bool viaKeyboard = false,
}) {
  final session = GenreModalSession(
    genre: genre,
    runner: TrackMenuRunner(ref, context),
    onQueueAction: onQueueAction,
    showGenre: showGenre,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: genreModalActionsPage(session),
      semanticLabel: context.l10n.genreModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
