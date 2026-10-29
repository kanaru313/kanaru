import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart'
    show translationServiceName;
import '../../playback_controls.dart';
import 'lyrics_translation_labels.dart';

/// Smallest room, in logical pixels, for which the translate button grows a
/// label; below it the button stays the round icon.
const lyricsTranslationMinLabelWidth = 64.0;

/// Width of the pill beside its label: padding, icon and the gap after it.
const lyricsTranslationPillChrome = 60.0;

/// Height of the pill, as tall as the round icon button beside it.
const _pillHeight = 40.0;

/// The translate button of translated lyrics: the active icon followed by
/// "service · language", on a raised stadium. The label is one line and
/// shrinks with an ellipsis to [maxLabelWidth]. Pressing it runs [onPressed].
class LyricsTranslationPill extends StatelessWidget {
  const LyricsTranslationPill({
    super.key,
    required this.state,
    required this.maxLabelWidth,
    required this.onPressed,
  });

  /// The state the pill shows; its credit is the label.
  final TranslationReady state;

  /// Most room the label may take.
  final double maxLabelWidth;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = l10n.lyricsTranslationButtonLabel(
      translationServiceName(state.service),
      translationLanguageName(l10n, state.info.effective),
    );
    return Tooltip(
      message: translationButtonTooltip(l10n, state),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(0, _pillHeight),
          maximumSize: const Size.fromHeight(_pillHeight),
          padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelMedium,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.lyricsTranslate,
              size: playerIconSize,
              // Null lets the button's disabled colour through.
              color: onPressed == null ? null : scheme.primary,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
