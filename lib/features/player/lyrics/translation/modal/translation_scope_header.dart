import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../l10n/l10n.dart';

/// Scope segments above a translation service list: which choice the pick
/// writes (this song only, the current queue, or the default for every song),
/// with, for the default, a line on how many
/// songs set individually, and whether the queue's choice, are affected: they
/// follow the new default with [TranslationScopePrecedence.replaceAll] or keep
/// their service with [TranslationScopePrecedence.keepCustom].
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
    required this.precedence,
    this.customCount = 0,
    this.queueHasChoice = false,
  });

  final List<TranslationScope> scopes;
  final TranslationScope selected;
  final ValueChanged<TranslationScope> onChanged;

  /// Scopes that cannot be chosen now, with the reason shown as a tooltip.
  final Map<TranslationScope, String> locked;

  /// How a pick for all songs treats songs and the queue set individually.
  final TranslationScopePrecedence precedence;

  /// Songs set individually that the caption speaks of: the ones a pick for
  /// all songs replaces ([TranslationScopePrecedence.replaceAll]) or leaves
  /// as they are ([TranslationScopePrecedence.keepCustom]).
  final int customCount;

  /// The current queue has an own choice the caption speaks of, replaced or
  /// kept the same way.
  final bool queueHasChoice;

  String _label(AppLocalizations l10n, TranslationScope scope) =>
      switch (scope) {
        TranslationScope.song => l10n.lyricsTranslationScopeSong,
        TranslationScope.all => l10n.lyricsTranslationScopeAll,
        TranslationScope.queue => l10n.lyricsTranslationScopeQueue,
      };

  String _caption(AppLocalizations l10n) => switch (precedence) {
    TranslationScopePrecedence.replaceAll =>
      queueHasChoice
          ? l10n.lyricsTranslationScopeReplacesWithQueue(customCount)
          : l10n.lyricsTranslationScopeReplaces(customCount),
    TranslationScopePrecedence.keepCustom =>
      queueHasChoice
          ? l10n.lyricsTranslationScopeKeepsWithQueue(customCount)
          : l10n.lyricsTranslationScopeKeeps(customCount),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Keeping songs says nothing when none is kept: a queue alone is not
    // worth a line then.
    final showCaption =
        selected == TranslationScope.all &&
        (customCount > 0 ||
            (queueHasChoice &&
                precedence == TranslationScopePrecedence.replaceAll));
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
          if (showCaption) ...[
            const SizedBox(height: 4),
            Text(
              _caption(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                // A warning only when songs will change; a note otherwise.
                color: precedence == TranslationScopePrecedence.replaceAll
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
