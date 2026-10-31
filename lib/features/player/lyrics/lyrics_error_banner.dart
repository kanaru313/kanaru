import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/lyrics_picker/lyrics_failure_message.dart';
import '../../../shared/lyrics_picker/lyrics_view_log_button.dart';
import 'lyrics_action_runner.dart';

/// Why the lookup failed (see [lyricsFailureMessage], which names the source
/// and says what went wrong) with Retry and, for a plugin that has a log
/// file, View log, at the top of the lyrics slot.
class LyricsErrorBanner extends StatelessWidget {
  const LyricsErrorBanner({
    super.key,
    required this.providerName,
    required this.canRetry,
    required this.failure,
    this.logProviderId,
  });

  /// The source the failure is put on, as the user reads it: a plugin's name
  /// (with its author or "(removed)" where that is needed) or LRCLIB.
  final String providerName;

  /// The plugin whose log View log shows; `null` when the failed source is
  /// LRCLIB or not known to be one plugin.
  final String? logProviderId;
  final bool canRetry;

  /// Why the lookup failed; `null` when it was not a request error.
  final LyricsFetchKind? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Icon(
                    AppIcons.warningRounded,
                    size: 20,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lyricsFailureMessage(l10n, failure, providerName),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
                  if (canRetry)
                    TextButton(
                      onPressed: () =>
                          LyricsActionRunner.snapshot(context).retry(),
                      child: Text(l10n.lyricsRetry),
                    ),
                  LyricsViewLogButton(providerId: logProviderId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
