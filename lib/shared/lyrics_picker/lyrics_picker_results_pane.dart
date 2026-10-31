import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import 'lyrics_failure_message.dart';
import 'lyrics_picker_result_tile.dart';
import 'lyrics_picker_result_sources.dart';
import 'lyrics_view_log_button.dart';

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
    this.sourceFilter,
    this.scrollController,
  });

  /// A search is about to start by itself (the song has a title), so an
  /// empty state is progress, not the note to type a query.
  final bool searchPending;

  final LyricsSearchState state;

  /// Display name by provider id.
  final Map<String, String> providerNames;

  /// Called with an index into `state.results`.
  final ValueChanged<int> onSelect;
  final VoidCallback onRetry;

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
    if (results.isEmpty) {
      if (failures.isNotEmpty) {
        return _Centered(
          children: [
            for (final f in failures)
              _FailureLine(
                providerId: f.key,
                providerName: providerNames[f.key] ?? f.key,
                kind: f.value.kind,
                onRetry: onRetry,
                centered: true,
              ),
          ],
        );
      }
      // No search has run and none is about to: the user types one.
      if (state.byProvider.isEmpty && !searchPending) {
        return _Centered(
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
        return const _Centered(children: [CircularProgressIndicator()]);
      }
      return _Centered(children: [Text(l10n.lyricsPickerEmpty)]);
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
          _FailureLine(
            providerId: f.key,
            providerName: providerNames[f.key] ?? f.key,
            kind: f.value.kind,
            onRetry: onRetry,
          ),
        // Ink and hover paint on the nearest Material, which would be the
        // dialog; this one inside the clip keeps them within the list.
        Expanded(
          child: ClipRect(
            child: Material(
              type: MaterialType.transparency,
              child: ListView.builder(
                controller: scrollController,
                itemCount: shown.length,
                itemBuilder: (context, row) {
                  final i = shown[row];
                  final id = results[i].candidate.providerId;
                  return LyricsPickerResultTile(
                    result: results[i],
                    selected: state.selected == i,
                    sourceName: providerNames[id] ?? id,
                    onTap: () => onSelect(i),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One failed source: what went wrong at it, Retry (not after withdrawn
/// consent, which trying again does not fix) and View log.
class _FailureLine extends StatelessWidget {
  const _FailureLine({
    required this.providerId,
    required this.providerName,
    required this.kind,
    required this.onRetry,
    this.centered = false,
  });

  final String providerId;
  final String providerName;
  final LyricsFetchKind? kind;
  final VoidCallback onRetry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Text(
      lyricsFailureMessage(l10n, kind, providerName),
      textAlign: centered ? TextAlign.center : TextAlign.start,
    );
    final actions = Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.end,
      children: [
        if (kind != LyricsFetchKind.notConsented)
          TextButton(onPressed: onRetry, child: Text(l10n.lyricsPickerRetry)),
        LyricsViewLogButton(providerId: providerId),
      ],
    );
    if (centered) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [text, actions],
        ),
      );
    }
    return ListTile(dense: true, title: text, subtitle: actions);
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}
