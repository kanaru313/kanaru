import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../l10n/l10n.dart';

/// Scope segments above a translation service list: which choice the pick
/// writes (this song only, or the default for every song), with a line that
/// explains the selected one and, for the default, how many songs set
/// individually would follow the new default.
///
/// [scopes] lists the segments shown, in order, so a caller can add the queue
/// segment. The queue scope has no label or hint yet: it needs its own
/// strings before it can be listed in [scopes] (an assert rejects it). A scope in [locked] stays visible but dimmed, and its tooltip is
/// the reason. The widget holds no state: the caller owns [selected].
class TranslationScopeHeader extends StatelessWidget {
  TranslationScopeHeader({
    super.key,
    required this.scopes,
    required this.selected,
    required this.onChanged,
    this.locked = const {},
    this.replacedCount = 0,
  }) : assert(
         !scopes.contains(TranslationScope.queue),
         'the queue scope needs its own label and hint',
       );

  final List<TranslationScope> scopes;
  final TranslationScope selected;
  final ValueChanged<TranslationScope> onChanged;

  /// Scopes that cannot be chosen now, with the reason shown as a tooltip.
  final Map<TranslationScope, String> locked;

  /// Songs with their own newer choice that a pick for all songs replaces.
  final int replacedCount;

  String _label(AppLocalizations l10n, TranslationScope scope) =>
      switch (scope) {
        TranslationScope.song => l10n.lyricsTranslationScopeSong,
        TranslationScope.all => l10n.lyricsTranslationScopeAll,
        // The queue tier has no segment label until it can be chosen.
        TranslationScope.queue => '',
      };

  String? _hint(AppLocalizations l10n) => switch (selected) {
    TranslationScope.song => l10n.lyricsTranslationScopeSongHint,
    TranslationScope.all => l10n.lyricsTranslationScopeAllHint,
    TranslationScope.queue => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = _hint(l10n);
    final showCaption = selected == TranslationScope.all && replacedCount > 0;
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
                  label: Text(_label(l10n, scope)),
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
              l10n.lyricsTranslationScopeReplaces(replacedCount),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
