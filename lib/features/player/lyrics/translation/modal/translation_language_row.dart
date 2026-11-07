import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_language.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/translation_language_name.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import '../../../../../shared/widgets/picker_field_button.dart';
import '../../../now_playing/now_playing_translation_toggle.dart';
import 'translation_pickers.dart';

/// Pause before an overflowing source language label starts scrolling.
const Duration _sourceMarqueeDelay = Duration(milliseconds: 300);

/// Resolve the read-only source language label from [state]:
/// `"<Language> · detected"` when [TranslationReady.sourceLang] resolves to a
/// known [TranslationLanguage], or `"Detected automatically"` otherwise.
String sourceLanguageLabel(
  AppLocalizations l10n,
  LyricsTranslationState state,
) {
  if (state case TranslationReady(:final sourceLang?)) {
    final lang =
        translationLanguageFor(sourceLang) ??
        translationLanguageFor(baseLanguageOf(sourceLang));
    if (lang != null) {
      return l10n.lyricsTranslationModalSourceDetected(
        translationLanguageName(l10n, lang),
      );
    }
  }
  return l10n.lyricsTranslationModalSourceAuto;
}

/// Language row of the "Translation" section: `[source label] (switch) [target ▾]`.
///
/// The source side is a read-only, non-focusable pill (same shape as the
/// target button, without the chevron) showing the detected source language
/// (or "Detected automatically"). The center [Switch] toggles
/// translation through [quickToggleLyricsTranslation] and opens the service
/// picker when no service is selected; it is disabled when no translate plugin
/// is installed. The right [PickerFieldButton] opens the target language
/// picker.
class TranslationLanguageRow extends ConsumerWidget {
  const TranslationLanguageRow({
    super.key,
    required this.state,
    required this.info,
    required this.appLang,
  });

  final LyricsTranslationState state;
  final TranslationTargetInfo info;
  final String appLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    // The service this song resolves to (its own choice or the default).
    final effective = info.choice?.service;
    final choices = ref.watch(translationServiceChoicesProvider);
    final noPlugins =
        choices.ready && choices.services.isEmpty && choices.selected == null;
    final on =
        prefs.show && (effective == null || !needsNoticeFor(prefs, effective));
    final sourceLabel = sourceLanguageLabel(l10n, state);
    final targetLabel = translationLanguageName(l10n, info.effective);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Expanded(child: _SourcePill(label: sourceLabel)),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.lyricsTranslationShow,
              child: Switch(
                value: on && !noPlugins,
                thumbIcon: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Icon(AppIcons.check)
                      : null,
                ),
                onChanged: noPlugins
                    ? null
                    : (_) => quickToggleLyricsTranslation(
                        context,
                        ref,
                        // The modal only opens while lyrics exist (no lyrics
                        // makes the state unavailable and closes it), so this
                        // row never needs to guard on lyrics itself.
                        hasLyrics: true,
                        songService: effective,
                        openModal: () => unawaited(
                          openServicePicker(context, ref, info: info),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickerFieldButton(
                label: targetLabel,
                onPressed: () => unawaited(
                  openTargetPicker(context, ref, info: info, appLang: appLang),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only source language pill: the geometry of [PickerFieldButton]
/// (stadium, 40 px high, 12 px side padding) without the chevron and without
/// any tap or focus behaviour.
class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            child: MarqueeText(
              text: label,
              startDelay: _sourceMarqueeDelay,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
