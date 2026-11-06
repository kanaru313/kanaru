import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import '../lyrics_translation_labels.dart';
import 'translation_language_row.dart';
import 'translation_modal_header.dart';
import 'translation_modal_navigation.dart';
import 'translation_preview_card.dart';
import 'translation_service_section.dart';

/// Opens the lyrics translation modal at depth 0 on the root navigator (a
/// 400 px centered dialog at or above 600 px, or a bottom sheet below).
Future<void> showLyricsTranslationModal(
  BuildContext context, {
  required String appLang,
}) {
  return showLayeredModal<void>(
    context,
    semanticLabel: context.l10n.lyricsTranslationButton,
    builder: (_) => LyricsTranslationModal(appLang: appLang),
  );
}

/// Parent modal for lyrics translation: the song header with settings and
/// close buttons, the live lyric line preview card, and the "Translation"
/// section (language row with switch, then service row or empty-plugins card).
///
/// Section order in the scrolling body:
/// 1. Preview card ([TranslationPreviewCard]).
/// 2. Translation section ([TranslationLanguageRow], [TranslationServiceSection]).
/// 3. Transliteration section (reserved after Translation, not rendered yet).
///
/// When [lyricsTranslationProvider] becomes [TranslationUnavailable] while the
/// modal is open, the entire modal stack (any open child picker or consent
/// dialog plus this parent modal) closes automatically.
class LyricsTranslationModal extends ConsumerStatefulWidget {
  const LyricsTranslationModal({super.key, required this.appLang});

  final String appLang;

  @override
  ConsumerState<LyricsTranslationModal> createState() =>
      _LyricsTranslationModalState();
}

class _LyricsTranslationModalState
    extends ConsumerState<LyricsTranslationModal> {
  bool _closing = false;

  void _scheduleCloseStack() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      closeTranslationModalStack(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lyricsTranslationProvider(widget.appLang));
    final info = translationInfoOf(state);
    if (info == null) {
      _scheduleCloseStack();
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    return LayeredModalBody(
      header: const TranslationModalHeader(),
      children: [
        TranslationPreviewCard(state: state),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Semantics(
            header: true,
            child: Text(
              l10n.lyricsTranslationModalSection,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        TranslationLanguageRow(
          state: state,
          info: info,
          appLang: widget.appLang,
        ),
        TranslationServiceSection(state: state),
      ],
    );
  }
}
