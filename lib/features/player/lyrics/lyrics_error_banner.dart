import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'lyrics_action_runner.dart';

/// "Couldn't reach {provider}" ("is busy" when it kept asking to wait) with
/// Retry, at the top of the lyrics slot.
class LyricsErrorBanner extends StatelessWidget {
  const LyricsErrorBanner({
    super.key,
    required this.providerName,
    required this.canRetry,
    required this.busy,
  });

  final String providerName;
  final bool canRetry;
  final bool busy;

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
                      (busy ? l10n.lyricsOnlineBusy : l10n.lyricsOnlineError)(
                        providerName,
                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
