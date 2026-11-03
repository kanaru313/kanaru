import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/stats/listen_recorder_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../history_clock.dart';
import 'history_page_modal_page.dart';
import 'history_page_modal_session.dart';

/// Opens the History modal. Everything the actions need from [ref] and
/// [context] is captured now, so the page may be gone when a row is picked.
/// Does nothing without an open library. [viaKeyboard] focuses the first row.
void openHistoryPageModal(
  WidgetRef ref,
  BuildContext context, {
  bool viaKeyboard = false,
}) {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final l10n = context.l10n;
  final session = HistoryPageModalSession(
    runner: TrackMenuRunner(ref, context),
    covers: ref.read(coverCacheDirectoryProvider),
    now: ref.read(historyNowProvider),
    recorder: ref.read(listenRecorderProvider),
  );
  unawaited(
    showContextModal<void>(
      context,
      root: historyPageModalActionsPage(session),
      semanticLabel: l10n.historyModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
