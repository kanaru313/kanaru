import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import '../lyrics_translation_labels.dart';
import 'translation_ai_tune_changes.dart';
import 'translation_preview_line.dart';

/// Pause before an overflowing provenance line starts scrolling.
const Duration _provenanceMarqueeDelay = Duration(milliseconds: 300);

/// Preview card under the translation modal header: a caption row with the
/// "PREVIEW" label and, while translation is on, a compact
/// [SegmentedButton] switching between `underLine` and `replace`; the current
/// lyric line drawn by [TranslationPreviewLine]; and the provenance line when
/// a translation is ready.
class TranslationPreviewCard extends ConsumerWidget {
  const TranslationPreviewCard({
    super.key,
    required this.state,
    this.onRetranslate,
  });

  final LyricsTranslationState state;
  final VoidCallback? onRetranslate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final settings = ref.read(settingsProvider.notifier);
    final effective = translationInfoOf(state)?.choice?.service;
    final choices = ref.watch(translationServiceChoicesProvider);
    final noPlugins =
        choices.ready && choices.services.isEmpty && choices.selected == null;
    final switchOn =
        prefs.show && (effective == null || !needsNoticeFor(prefs, effective));
    final active = (switchOn && !noPlugins) || translationIsActive(state);
    final plugins = ref.watch(translationPluginInfosProvider);

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
              if (state
                  case TranslationReady(
                    :final service,
                    :final fromOtherService,
                    :final refreshing,
                    :final settingsJson,
                  )
                  when active)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ProvenanceRow(
                    serviceName: translationServiceName(l10n, plugins, service),
                    fromOtherService: fromOtherService,
                    refreshing: refreshing,
                    styleTitle: _styleTitle(ref, service, settingsJson),
                    onRetranslate: onRetranslate,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The style the shown translation was made with, from its snapshot.
String? _styleTitle(
  WidgetRef ref,
  TranslationServiceId service,
  String? settingsJson,
) {
  final tune = ref.watch(translationAiTunesProvider)[service];
  return tune == null ? null : aiSnapshotStyleTitle(tune, settingsJson);
}

class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({
    required this.serviceName,
    required this.fromOtherService,
    required this.refreshing,
    required this.styleTitle,
    required this.onRetranslate,
  });

  /// Title of the style in the snapshot of the shown version; null when it
  /// has none.
  final String? styleTitle;
  final String serviceName;
  final bool fromOtherService;
  final bool refreshing;
  final VoidCallback? onRetranslate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.outline,
    );
    final text = refreshing
        ? l10n.lyricsTranslationModalRefreshingNote
        : fromOtherService
        ? l10n.lyricsTranslationModalOtherVersion(serviceName)
        : styleTitle != null
        ? l10n.lyricsTranslationModalTranslatedByWithStyle(
            serviceName,
            styleTitle!,
          )
        : l10n.lyricsTranslationModalTranslatedBy(serviceName);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refreshing) ...[
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: MarqueeText(
              text: text,
              startDelay: _provenanceMarqueeDelay,
              style: textStyle,
            ),
          ),
          if (!refreshing && !fromOtherService) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: l10n.lyricsTranslationRetranslate,
              icon: const Icon(AppIcons.refresh, size: 18),
              color: colors.outline,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: onRetranslate,
            ),
          ],
        ],
      ),
    );
  }
}
