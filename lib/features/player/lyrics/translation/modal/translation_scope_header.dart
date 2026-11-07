import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../l10n/l10n.dart';

/// Scope segments above a translation service list: which choice the pick
/// writes (this song only, the current queue, or the default for every song),
/// with a line that explains the selected one and, for the default, how many
/// songs set individually, and whether the queue's choice, would follow the
/// new default.
///
/// [scopes] lists the segments shown, in order. A scope in [locked] stays
/// visible but dimmed, and its tooltip is the reason. The widget holds no
/// state: the caller owns [selected].
class TranslationScopeHeader extends StatelessWidget {
  const TranslationScopeHeader({
    super.key,
    required this.scopes,
    required this.selected,
    required this.onChanged,
    this.locked = const {},
    this.replacedCount = 0,
    this.replacesQueue = false,
  });

  final List<TranslationScope> scopes;
  final TranslationScope selected;
  final ValueChanged<TranslationScope> onChanged;

  /// Scopes that cannot be chosen now, with the reason shown as a tooltip.
  final Map<TranslationScope, String> locked;

  /// Songs with their own newer choice that a pick for all songs replaces.
  final int replacedCount;

  /// The current queue's own newer choice is replaced by a pick for all songs.
  final bool replacesQueue;

  String _label(AppLocalizations l10n, TranslationScope scope) =>
      switch (scope) {
        TranslationScope.song => l10n.lyricsTranslationScopeSong,
        TranslationScope.all => l10n.lyricsTranslationScopeAll,
        TranslationScope.queue => l10n.lyricsTranslationScopeQueue,
      };

  String? _hint(AppLocalizations l10n) => switch (selected) {
    TranslationScope.song => l10n.lyricsTranslationScopeSongHint,
    TranslationScope.all => l10n.lyricsTranslationScopeAllHint,
    TranslationScope.queue => l10n.lyricsTranslationScopeQueueHint,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = _hint(l10n);
    final showCaption =
        selected == TranslationScope.all &&
        (replacedCount > 0 || replacesQueue);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TranslationScope>(
            showSelectedIcon: false,
            segments: [
              for (final scope in scopes)
                ButtonSegment(
                  value: scope,
                  // One line, scaled down when a locale's label is wider than its
                  // segment.
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _label(l10n, scope),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  enabled: !locked.containsKey(scope),
                  tooltip: locked[scope],
                ),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.single),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (showCaption) ...[
            const SizedBox(height: 4),
            Text(
              replacesQueue
                  ? l10n.lyricsTranslationScopeReplacesWithQueue(replacedCount)
                  : l10n.lyricsTranslationScopeReplaces(replacedCount),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
