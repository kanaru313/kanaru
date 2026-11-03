import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../core/database/library_startup.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import 'most_played_modal_page.dart';
import 'most_played_modal_session.dart';

/// Opens the Most played modal on the ranking [rows] now on show, described
/// by [rangeText] and [totals]. The modal acts on that snapshot (its library
/// songs, in rank order) even if the ranking reloads meanwhile. Everything
/// the actions need from [ref] and [context] is captured now, so the page may
/// be gone when a row is picked. Does nothing without an open library.
/// [viaKeyboard] focuses the first row.
void openMostPlayedModal(
  WidgetRef ref,
  BuildContext context, {
  required List<HistoryTopRow> rows,
  required String rangeText,
  required HistoryRangeSummary? totals,
  bool viaKeyboard = false,
}) {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final l10n = context.l10n;
  final session = MostPlayedModalSession(
    rows: rows,
    covers: ref.read(coverCacheDirectoryProvider),
    rangeText: rangeText,
    totals: totals,
    runner: TrackMenuRunner(ref, context),
    db: db,
    l10n: l10n,
    messenger: ScaffoldMessenger.of(context),
    rootNavigator: Navigator.maybeOf(context, rootNavigator: true),
    save: ref.read(m3uSavePickerProvider),
  );
  unawaited(
    showContextModal<void>(
      context,
      root: mostPlayedModalPage(session),
      semanticLabel: l10n.mostPlayedModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
