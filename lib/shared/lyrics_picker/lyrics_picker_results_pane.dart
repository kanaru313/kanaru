import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import 'lyrics_failure_message.dart';
import 'lyrics_picker_result_tile.dart';

/// The left side of the Choose lyrics dialog: progress while searching, the
/// results, "no lyrics found", the error with Retry and, before the first
/// search of a song without a title, a note to type the query.
class LyricsPickerResultsPane extends StatelessWidget {
  const LyricsPickerResultsPane({
    super.key,
    required this.state,
    required this.providerNames,
    required this.onSelect,
    required this.onRetry,
    this.searchPending = false,
  });

  /// A search is about to start by itself (the song has a title), so an
  /// empty state is progress, not the note to type a query.
  final bool searchPending;

  final LyricsSearchState state;

  /// Display name by provider id.
  final Map<String, String> providerNames;
  final ValueChanged<int> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = state.byProvider.entries
        .where((e) => e.value.phase == ProviderSearchPhase.error)
        .firstOrNull;
    final failed = failure == null
        ? null
        : providerNames[failure.key] ?? failure.key;
    // Withdrawn consent is not fixed by trying again.
    final canRetry = failure?.value.kind != LyricsFetchKind.notConsented;
    final failedText = failed == null
        ? ''
        : lyricsFailureMessage(l10n, failure?.value.kind, failed);
    final results = state.results;
    if (results.isEmpty) {
      if (failed != null) {
        return _Centered(
          children: [
            Text(failedText, textAlign: TextAlign.center),
            if (canRetry) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.lyricsPickerRetry),
              ),
            ],
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
    return Column(
      children: [
        if (state.searching) const LinearProgressIndicator(),
        if (failed != null)
          ListTile(
            dense: true,
            title: Text(failedText),
            trailing: canRetry
                ? TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.lyricsPickerRetry),
                  )
                : null,
          ),
        // Ink and hover paint on the nearest Material, which would be the
        // dialog; this one inside the clip keeps them within the list.
        Expanded(
          child: ClipRect(
            child: Material(
              type: MaterialType.transparency,
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => LyricsPickerResultTile(
                  result: results[i],
                  selected: state.selected == i,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
