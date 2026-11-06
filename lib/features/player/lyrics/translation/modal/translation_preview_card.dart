import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import '../lyrics_translation_labels.dart';
import 'translation_preview_line.dart';

/// Pause before an overflowing provenance line starts scrolling.
const Duration _provenanceMarqueeDelay = Duration(milliseconds: 300);

/// Preview card under the translation modal header: a caption row with the
/// "PREVIEW" label and, while translation is on, a compact
/// [SegmentedButton] switching between `underLine` and `replace`; the current
/// lyric line drawn by [TranslationPreviewLine]; and the service credit line
/// when a translation is ready.
class TranslationPreviewCard extends ConsumerWidget {
  const TranslationPreviewCard({super.key, required this.state});

  final LyricsTranslationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final settings = ref.read(settingsProvider.notifier);
    final effective = ref.watch(effectiveTranslationServiceProvider);
    final choices = ref.watch(translationServiceChoicesProvider);
    final noPlugins =
        choices.ready && choices.services.isEmpty && choices.selected == null;
    final switchOn =
        prefs.show && (effective == null || !needsNoticeFor(prefs, effective));
    final active = (switchOn && !noPlugins) || translationIsActive(state);
    final plugins = ref.watch(translationPluginInfosProvider);

    String? credit;
    if (state case TranslationReady(:final service) when active) {
      final name = translationServiceName(l10n, plugins, service);
      credit = l10n.lyricsTranslationModalTranslatedBy(name);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.lyricsTranslationModalPreview.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.outline,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (active)
                    SegmentedButton<LyricsTranslationDisplay>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: const VisualDensity(
                          horizontal: -3,
                          vertical: -3,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: theme.textTheme.labelSmall,
                      ),
                      segments: [
                        ButtonSegment(
                          value: LyricsTranslationDisplay.underLine,
                          label: Text(l10n.lyricsTranslationModalDisplayUnder),
                        ),
                        ButtonSegment(
                          value: LyricsTranslationDisplay.replace,
                          label: Text(
                            l10n.lyricsTranslationModalDisplayReplace,
                          ),
                        ),
                      ],
                      selected: {prefs.display},
                      onSelectionChanged: (s) => settings.setTranslation(
                        prefs.copyWith(display: s.single),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TranslationPreviewLine(
                state: state,
                display: prefs.display,
                showTranslation: active,
              ),
              if (credit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: MarqueeText(
                      text: credit,
                      startDelay: _provenanceMarqueeDelay,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
