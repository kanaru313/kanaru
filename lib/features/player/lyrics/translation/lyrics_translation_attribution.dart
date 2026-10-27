import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart'
    show translationServiceName;
import 'lyrics_translation_labels.dart';
import 'lyrics_translation_menu.dart';

/// The credit at the bottom end of translated lyrics: "Translated by
/// service · language" (the service whose row is on screen), or, when the
/// lyrics are already in the target language, a note saying so. Pressing it
/// opens the translation menu there. [state] is a [TranslationReady] or a
/// [TranslationSameLanguage].
class LyricsTranslationAttribution extends ConsumerWidget {
  const LyricsTranslationAttribution({
    super.key,
    required this.state,
    required this.appLang,
  });

  final LyricsTranslationState state;
  final String appLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = translationInfoOf(state);
    if (info == null) return const SizedBox.shrink();
    final language = translationLanguageName(l10n, info.effective);
    final text = switch (state) {
      TranslationReady(:final service) => l10n.lyricsTranslationAttribution(
        translationServiceName(service),
        language,
      ),
      _ => l10n.lyricsTranslationSameLanguage(
        languageNameInSentence(l10n, language),
      ),
    };
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Padding(
        // The ambient bottom padding is the room an overlay (the Lyrics-only
        // strip) takes at the bottom.
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          16,
          8 + MediaQuery.paddingOf(context).bottom,
        ),
        child: MenuAnchor(
          menuChildren: lyricsTranslationMenuItems(
            context,
            ref,
            state,
            appLang,
          ),
          builder: (context, controller, _) => TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.8,
              ),
              textStyle: theme.textTheme.labelMedium,
            ),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
