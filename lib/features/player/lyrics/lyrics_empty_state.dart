import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';

/// Shown in the lyrics slot of Now Playing when the song has no lyrics: an
/// icon and a title, centered, with an optional row of [actions] below. It is
/// small on purpose, since it also fills the side pane and the narrow page.
class LyricsEmptyState extends StatelessWidget {
  const LyricsEmptyState({super.key, this.title, this.actions = const []});

  /// The headline; the localized "No lyrics for this song" when `null`.
  final String? title;

  /// Buttons under the title; none by default.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.lyrics, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title ?? context.l10n.lyricsNone,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
