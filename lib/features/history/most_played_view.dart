import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/playlist_cover_keys.dart';
import '../../l10n/l10n.dart';
import '../../shared/in_page_filter.dart';
import '../../shared/in_page_filter_host.dart';
import '../../shared/widgets/detail_page/play_shuffle_actions.dart';
import '../../shared/widgets/detail_page/tracks_toolbar.dart';
import 'history_clock.dart';
import 'history_providers.dart';
import 'history_range.dart';
import 'history_range_bar.dart';
import 'history_range_span.dart';
import 'history_two_column_layout.dart';
import 'most_played_actions.dart';
import 'most_played_body.dart';
import 'most_played_range_picker.dart';
import 'most_played_side_pane.dart';
import 'most_played_totals.dart';

/// The Most played page: the songs played most in a range of days, ranked,
/// in the History page's two columns. The pane (a header in a narrow window)
/// names the range and its totals and plays the ranking; the right column has
/// the filter, the range bar and the list. Its range lives in this widget's
/// state, so it survives a switch to another page.
///
/// While a new range or a change to the plays is read, the list on show
/// stays and a thin bar runs over it, so the list never flashes empty.
class MostPlayedView extends ConsumerStatefulWidget {
  const MostPlayedView({super.key});

  @override
  ConsumerState<MostPlayedView> createState() => _MostPlayedViewState();
}

class _MostPlayedViewState extends ConsumerState<MostPlayedView>
    with InPageFilterHost<MostPlayedView> {
  var _range = const HistoryRangeState();
  final _filter = InPageFilterController();
  final _filterView = InPageFilterView<HistoryTopRow>((row) {
    final track = row.track;
    return (
      title: track?.title ?? row.path.split('/').last,
      artist: track?.artist,
      album: track?.album,
    );
  });

  /// The ranking on show; kept while the next range is read.
  final _shown = MostPlayedRows();

  @override
  InPageFilterController get filterController => _filter;

  @override
  bool get filterAvailable => _shown.rows?.isNotEmpty ?? false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _pickCustom(DateTime now) async {
    final next = await pickMostPlayedCustom(context, ref, _range, now);
    if (next == null || !mounted) return;
    setState(() => _range = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.watch(historyNowProvider)();
    final played = ref.watch(historyPlayedRangeProvider);
    final playedRange = played.value;
    var loading = played.isLoading;
    var failed = played.hasError;
    ({int start, int end})? window;
    if (played.hasValue && playedRange == null) {
      _shown.keep(const []);
    } else if (playedRange != null) {
      window = _range.window(now);
      if (window != null && windowCoversPlays(window, playedRange)) {
        window = null;
      }
      final top = ref.watch(
        historyTopProvider(
          window == null
              ? (start: null, end: null)
              : (start: window.start, end: window.end),
        ),
      );
      if (top.hasValue) _shown.keep(top.value!);
      loading = top.isLoading;
      failed = top.hasError;
    }
    final rows = _shown.rows;
    final totals = watchMostPlayedTotals(
      ref,
      window,
      playedKnown: played.hasValue,
      anyPlayed: playedRange != null,
    );
    final rangeText = historyRangeText(context, _range, now);
    final playable = rows?.any((r) => r.track != null) ?? false;

    final actions = PlayShuffleActions(
      playLabel: l10n.albumsPlay,
      onPlay: playable ? () => playMostPlayed(ref, rows!) : null,
      onShuffle: playable ? () => shuffleMostPlayed(ref, rows!) : null,
      onQueueAction: null,
      menu: MostPlayedMenuButton(
        enabled: playable,
        onSelected: (choice) =>
            runMostPlayedChoice(ref, context, choice, rows!, rangeText),
      ),
    );
    final summary = totals == null
        ? null
        : [
            l10n.albumsSongCount(totals.tracks),
            l10n.historyListenCount(totals.plays),
          ].join(' · ');
    final rangeLine = mostPlayedRangeLine(context, _range, now);
    final coverKeys = pickCollageKeys([
      for (final row in rows ?? const <HistoryTopRow>[]) row.track?.coverKey,
    ]);

    return Material(
      type: MaterialType.transparency,
      child: HistoryTwoColumnLayout(
        tintKeys: [...coverKeys]..sort(),
        pane: MostPlayedSidePane(
          coverKeys: coverKeys,
          rangeLine: rangeLine,
          summary: summary,
          actions: actions,
        ),
        header: MostPlayedHeader(
          coverKeys: coverKeys,
          rangeLine: rangeLine,
          summary: summary,
          actions: actions,
        ),
        column: ListenableBuilder(
          listenable: _filter,
          builder: (context, _) {
            // The positions the filter lets through; the toolbar counts
            // these, the body shows them.
            final terms = _filter.terms;
            final ranks = rows == null
                ? const <int>[]
                : terms.isEmpty
                ? [for (var i = 0; i < rows.length; i++) i]
                : ([..._filterView.rank(rows, terms)]..sort());
            return Column(
              children: [
                TracksToolbar(
                  summary: l10n.albumsSongCount(ranks.length),
                  filter: _filter,
                ),
                HistoryRangeBar(
                  state: _range,
                  now: now,
                  canPickCustom: playedRange != null,
                  onPreset: (p) =>
                      setState(() => _range = _range.withPreset(p)),
                  onCustom: () => unawaited(_pickCustom(now)),
                  onShift: (d) => setState(
                    () => _range = d < 0 ? _range.previous() : _range.next(),
                  ),
                ),
                SizedBox(
                  height: 2,
                  child: loading ? const LinearProgressIndicator() : null,
                ),
                Expanded(
                  child: MostPlayedBody(
                    loading: loading,
                    failed: failed,
                    rows: rows,
                    ranks: ranks,
                    capped: _shown.capped,
                    query: _filter.query,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
