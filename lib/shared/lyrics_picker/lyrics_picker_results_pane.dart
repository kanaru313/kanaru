import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import 'lyrics_picker_result_tile.dart';

/// The left side of the Choose lyrics dialog: progress while searching, the
/// results, "no lyrics found" and the error with Retry.
class LyricsPickerResultsPane extends StatelessWidget {
  const LyricsPickerResultsPane({
    super.key,
    required this.state,
    required this.providerNames,
    required this.onSelect,
    required this.onRetry,
  });

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
        : canRetry
        ? l10n.lyricsPickerError(failed)
        : l10n.lyricsPickerNotConsented(failed);
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
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) => LyricsPickerResultTile(
              result: results[i],
              selected: state.selected == i,
              onTap: () => onSelect(i),
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
