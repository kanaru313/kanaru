import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../core/database/library_startup.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../history_clock.dart';
import '../history_delete_undo.dart';
import '../history_error_log.dart';
import '../history_plays_version.dart';
import 'history_day_modal_data.dart';
import 'history_day_modal_page.dart';
import 'history_day_modal_session.dart';

/// Opens the Day modal for [day]. The modal works on the plays the page shows
/// for the day: [readDay] reads them when the modal is asked for (with the
/// page's cut of plays that are held back) and that snapshot is what every
/// action uses. A play recorded while the modal is open is never part of it,
/// so Remove deletes exactly the rows the reader saw.
///
/// Everything the actions need from [ref] and [context] is captured before
/// the first `await`: the page may be gone when a row is picked. After the
/// read the modal opens only if [context] is still mounted and its branch is
/// the one on screen (branches stay mounted offstage); otherwise it is
/// dropped silently. A failed read is logged and said in a snackbar.
/// [viaKeyboard] focuses the first row. Returns once the modal is open.
Future<void> openHistoryDayModal(
  WidgetRef ref,
  BuildContext context, {
  required DateTime day,
  required Future<List<HistoryPlayRow>> Function() readDay,
  bool viaKeyboard = false,
}) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final covers = ref.read(coverCacheDirectoryProvider);
  final now = ref.read(historyNowProvider)();
  final runner = TrackMenuRunner(ref, context);
  final save = ref.read(m3uSavePickerProvider);
  final version = ref.read(historyPlaysVersionProvider.notifier);
  final undo = ref.read(historyDeleteUndoProvider);
  final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
  final List<HistoryPlayRow> rows;
  try {
    rows = await readDay();
  } on Object catch (error) {
    logHistoryError('Opening the modal of a day failed', error);
    if (messenger.mounted) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
    }
    return;
  }
  if (!context.mounted || !TickerMode.valuesOf(context).enabled) return;
  final session = HistoryDayModalSession(
    data: HistoryDayModalData(day: day, rows: rows, covers: covers),
    now: now,
    runner: runner,
    db: db,
    l10n: l10n,
    messenger: messenger,
    rootNavigator: rootNavigator,
    save: save,
    version: version,
    undo: undo,
  );
  unawaited(
    showContextModal<void>(
      context,
      root: historyDayModalActionsPage(session),
      semanticLabel: l10n.historyDayMenu,
      viaKeyboard: viaKeyboard,
    ),
  );
}
