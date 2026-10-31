import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart';
import '../../../../shared/widgets/menu_row.dart';
import 'lyrics_translation_labels.dart';

/// Widest the footer text grows before it wraps.
const _maxWidth = 280.0;

/// The note about the translation on screen and the action that goes with
/// it; nothing while translation is off.
List<Widget> lyricsTranslationMenuFooter(
  BuildContext context,
  LyricsTranslationState state,
  LyricsTranslationService selected,
  LyricsTranslationController controller,
) {
  final l10n = context.l10n;
  final (String? text, String? action, VoidCallback? run) = switch (state) {
    TranslationReady(:final service, :final fromOtherService) => (
      fromOtherService
          ? l10n.lyricsTranslationSavedFrom(translationServiceName(service))
          : l10n.lyricsTranslationSaved,
      fromOtherService
          ? l10n.lyricsTranslationRetranslateWith(
              translationServiceName(selected),
            )
          : l10n.lyricsTranslationRetranslate,
      controller.retranslate,
    ),
    TranslationSameLanguage(:final info) => (
      l10n.lyricsTranslationSameLanguage(
        languageNameInSentence(
          l10n,
          translationLanguageName(l10n, info.effective),
        ),
      ),
      null,
      null,
    ),
    TranslationLoading() => (
      l10n.lyricsTranslationLoading,
      l10n.lyricsTranslationRetranslate,
      null,
    ),
    TranslationFailed(:final kind) => (
      translationFailureMessage(l10n, kind),
      l10n.lyricsTranslationRetry,
      controller.retry,
    ),
    _ => (null, null, null),
  };
  if (text == null) return const [];
  return [
    const Divider(height: 1),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ),
    if (action != null)
      // Stays open so the footer shows the new state.
      menuRowSpaced(
        MenuItemButton(
          style: menuRowStyle(),
          closeOnActivate: false,
          onPressed: run,
          child: Text(action),
        ),
      ),
  ];
}
