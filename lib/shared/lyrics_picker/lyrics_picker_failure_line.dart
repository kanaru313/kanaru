import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import 'lyrics_failure_message.dart';
import 'lyrics_view_log_button.dart';

/// One failed source: what went wrong at it, Retry (not after withdrawn
/// consent, which trying again does not fix) and View log.
class LyricsPickerFailureLine extends StatelessWidget {
  const LyricsPickerFailureLine({
    super.key,
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

/// Centers its [children] in the results pane.
class LyricsPickerCentered extends StatelessWidget {
  const LyricsPickerCentered({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// The failure text of the selected result's lyrics fetch, or `null` when it
/// did not fail.
String? lyricsSelectionFailure(
  AppLocalizations l10n,
  LyricsSearchState state,
  Map<String, String> providerNames,
) {
  final fetch = state.selectionFetch;
  if (fetch?.phase != BodyFetchPhase.failed) return null;
  return lyricsFailureMessage(
    l10n,
    fetch?.kind,
    providerNames[state.selection?.candidate.providerId] ?? '',
  );
}
