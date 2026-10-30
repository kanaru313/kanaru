import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Above the source list: how the order works, and the Plugin store button.
/// The button is shown but disabled (with a "Coming soon" tooltip) until the
/// store exists.
class LyricsSourcesHeader extends StatelessWidget {
  const LyricsSourcesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.info,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.lyricsSourcesInfo,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: l10n.lyricsSourcesStoreSoon,
            child: FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.lyricsSourcesStore),
            ),
          ),
        ],
      ),
    );
  }
}
