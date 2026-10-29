import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart'
    show translationServiceName;
import '../../now_playing/now_playing_header_pill.dart';
import 'lyrics_translation_labels.dart';

/// Smallest room, in logical pixels, for which the translate button grows a
/// label; below it the button stays the round icon.
const lyricsTranslationMinLabelWidth = 64.0;

/// Width of the pill beside its label: padding, icon and the gap after it.
const lyricsTranslationPillChrome = 60.0;

/// The translate button of translated lyrics: the active icon followed by
/// "service · language", as a [NowPlayingHeaderPill]. Pressing it runs
/// [onPressed].
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
    return NowPlayingHeaderPill(
      icon: AppIcons.lyricsTranslate,
      label: l10n.lyricsTranslationButtonLabel(
        translationServiceName(state.service),
        translationLanguageName(l10n, state.info.effective),
      ),
      tooltip: translationButtonTooltip(l10n, state),
      maxLabelWidth: maxLabelWidth,
      onPressed: onPressed,
    );
  }
}
