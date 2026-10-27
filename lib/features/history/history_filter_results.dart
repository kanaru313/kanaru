import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/in_page_no_match.dart';
import 'history_day_queue.dart';
import 'history_line_metrics.dart';
import 'history_play_menu_actions.dart';
import 'history_play_row_tile.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';

/// The plays of a year whose song matches the in-page filter, newest first,
/// as one flat list of the timeline's rows (no day bars). A tap plays the
/// matched songs, each once, from the tapped one.
///
/// The answer on show stays while the next one is read, with a thin bar over
/// it, so typing never flashes the list empty.
class HistoryFilterResults extends ConsumerStatefulWidget {
  const HistoryFilterResults({
    super.key,
    required this.year,
    required this.terms,
    required this.query,
  });

  final int year;

  /// The filter terms; never empty.
  final List<String> terms;

  /// What was typed, for the message when nothing matches.
  final String query;

  @override
  ConsumerState<HistoryFilterResults> createState() =>
      _HistoryFilterResultsState();
}

class _HistoryFilterResultsState extends ConsumerState<HistoryFilterResults>
    with HistoryPlayMenuActions<HistoryFilterResults> {
  /// The last answer read; stays on show while the next one is read.
  HistoryMatches? _shown;

  @override
  void didUpdateWidget(HistoryFilterResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rows of another year must never stay on show (or be tappable).
    if (oldWidget.year != widget.year) _shown = null;
  }

  void _play(List<HistoryPlayRow> rows, HistoryPlayRow tapped) {
    final queue = historyDayQueue(
      rows,
      tapped,
      ref.read(coverCacheDirectoryProvider),
    );
    if (queue != null) playTracks(ref, queue.tracks, queue.start);
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(
      historyMatchesProvider((
        year: widget.year,
        terms: widget.terms.join(' '),
      )),
    );
    if (matches.hasValue) _shown = matches.value;
    // The latest read failed: say so rather than show an older answer.
    if (matches.hasError && !matches.isLoading) {
      _shown = null;
      return const HistoryLoadFailed();
    }
    final shown = _shown;
    final loading = matches.isLoading;
    if (shown == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final extent = historyLineExtent(theme, MediaQuery.textScalerOf(context));
    final rows = shown.rows;
    final Widget body;
    if (rows.isEmpty) {
      body = loading
          ? const SizedBox.shrink()
          : SingleChildScrollView(child: InPageNoMatch(query: widget.query));
    } else {
      body = ListView.builder(
        itemExtent: extent,
        itemCount: rows.length + (shown.truncated ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
              child: Text(
                context.l10n.historyTopCapped(historyFilterLimit),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final row = rows[i];
          return HistoryPlayRowTile(
            key: ValueKey(row.id),
            row: row,
            onTap: () => _play(rows, row),
            onMenu: (position) => unawaited(openPlayMenu(row, position)),
          );
        },
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 2,
          child: loading ? const LinearProgressIndicator() : null,
        ),
        Expanded(child: body),
      ],
    );
  }
}
