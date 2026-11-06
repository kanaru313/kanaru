import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import '../widgets/scroll_ink_surface.dart';
import 'lyrics_picker_failure_line.dart';
import 'lyrics_picker_result_tile.dart';
import 'lyrics_picker_result_sources.dart';

/// The left side of the Choose lyrics dialog: progress while searching, the
/// results (each with its source, narrowed to one source by the filter in the
/// search row), "no lyrics found", one line per source that
/// failed, with Retry and, for a plugin with a log, View log, and, before the
/// first search of a song without a title, a note to type the query.
class LyricsPickerResultsPane extends StatelessWidget {
  const LyricsPickerResultsPane({
    super.key,
    required this.state,
    required this.providerNames,
    required this.onSelect,
    required this.onRetry,
    this.searchPending = false,
    this.noSource = false,
    this.sourceFilter,
    this.scrollController,
    this.offSourcesCard,
  });

  /// A search is about to start by itself (the song has a title), so an
  /// empty state is progress, not the note to type a query.
  final bool searchPending;

  /// No online lyrics source is on, so no search can run or end with results.
  final bool noSource;

  final LyricsSearchState state;

  /// Display name by provider id.
  final Map<String, String> providerNames;

  /// Called with an index into `state.results`.
  final ValueChanged<int> onSelect;

  /// Called with the id of the source whose failure line was retried.
  final ValueChanged<String> onRetry;

  /// Offers the off sources not searched yet; shown under the empty states
  /// and as the last item of the list.
  final Widget? offSourcesCard;

  /// The provider id the list is filtered to; `null` shows every source. One
  /// that returned no results (a new search) counts as `null`.
  final String? sourceFilter;

  /// Controls the result list, so the owner can scroll it back to the top.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failures = [
      for (final e in state.byProvider.entries)
        if (e.value.phase == ProviderSearchPhase.error) e,
    ];
    final results = state.results;
    final card = offSourcesCard;
    if (results.isEmpty) {
      if (failures.isNotEmpty) {
        return LyricsPickerCentered(
          children: [
            for (final f in failures)
              LyricsPickerFailureLine(
                providerId: f.key,
                providerName: providerNames[f.key] ?? f.key,
                kind: f.value.kind,
                onRetry: () => onRetry(f.key),
                centered: true,
              ),
            ?card,
          ],
        );
      }
      if (noSource) {
        return LyricsPickerCentered(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                card == null
                    ? l10n.lyricsPickerNoSource
                    : l10n.lyricsPickerNoneOn,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?card,
          ],
        );
      }
      // No search has run and none is about to: the user types one.
      if (state.byProvider.isEmpty && !searchPending) {
        return LyricsPickerCentered(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.lyricsPickerBlankHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }
      if (state.searching || state.byProvider.isEmpty) {
        return const LyricsPickerCentered(
          children: [CircularProgressIndicator()],
        );
      }
      return LyricsPickerCentered(
        children: [Text(l10n.lyricsPickerEmpty), ?card],
      );
    }
    final filter = effectiveSourceFilter(
      sourceFilter,
      lyricsResultSources(results),
    );
    final shown = [
      for (var i = 0; i < results.length; i++)
        if (filter == null || results[i].candidate.providerId == filter) i,
    ];
    return Column(
      children: [
        if (state.searching) const LinearProgressIndicator(),
        for (final f in failures)
          LyricsPickerFailureLine(
            providerId: f.key,
            providerName: providerNames[f.key] ?? f.key,
            kind: f.value.kind,
            onRetry: () => onRetry(f.key),
          ),
        // Ink and hover paint on the nearest Material, which would be the
        // dialog; this one inside the clip keeps them within the list.
        Expanded(
          child: ScrollInkSurface(
            child: ListView.builder(
              controller: scrollController,
              itemCount: shown.length + (card == null ? 0 : 1),
              itemBuilder: (context, row) {
                if (row == shown.length) return card!;
                final i = shown[row];
                final id = results[i].candidate.providerId;
                return LyricsPickerResultTile(
                  result: results[i],
                  selected: state.selected == i,
                  sourceName: providerNames[id] ?? id,
                  sourceOff: state.onDemand.contains(id),
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
