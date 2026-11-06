import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/lyrics_plugin_spec.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/lyrics_plugins/plugin_icon.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import '../lyrics_translation_labels.dart';
import 'translation_ai_badge.dart';
import 'translation_ai_tune_row.dart';
import 'translation_modal_navigation.dart';
import 'translation_pickers.dart';

/// Pause before an overflowing service row text starts scrolling.
const Duration _serviceMarqueeDelay = Duration(milliseconds: 300);

/// Service area below the language row: shown when translation is on or when
/// no service is in effect (so opening the modal via `T` or secondary click
/// immediately shows what is needed).
///
/// Renders the empty-plugins card with a button to open the plugin store when
/// no translate plugin is installed, or the service row that opens
/// [openServicePicker] when plugins exist.
class TranslationServiceSection extends ConsumerWidget {
  const TranslationServiceSection({super.key, required this.state});

  final LyricsTranslationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final choices = ref.watch(translationServiceChoicesProvider);
    final showSection =
        prefs.show || translationIsActive(state) || choices.selected == null;
    if (!showSection) return const SizedBox.shrink();

    if (choices.ready && choices.services.isEmpty && choices.selected == null) {
      return const _NoPluginsCard();
    }
    final selected = choices.selected;
    final tune = choices.ready && selected != null
        ? ref.watch(translationAiTunesProvider)[selected]
        : null;
    final hash = translationInfoOf(state)?.hash;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ServiceRow(choices: choices),
        if (tune != null && selected != null && hash != null)
          TranslationAiTuneRow(service: selected, hash: hash),
      ],
    );
  }
}

class _NoPluginsCard extends StatelessWidget {
  const _NoPluginsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.extension, size: 36, color: colors.primary),
              const SizedBox(height: 6),
              Text(
                l10n.lyricsTranslationModalNoPluginsTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.lyricsTranslationNeedsPlugin,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => openTranslationStore(context),
                child: Text(l10n.lyricsTranslationOpenPluginStore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({required this.choices});

  final TranslationServiceChoices choices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plugins = ref.watch(translationPluginInfosProvider);
    final selected = choices.selected;
    final ready = choices.ready;
    final unset = ready && selected == null;
    final selectedId = selected?.value;
    // The selected plugin's record, for its own icon; null while records load.
    final record = ref.watch(
      lyricsPluginRecordsProvider.select((records) {
        for (final r in records) {
          if (r.installId == selectedId) return r;
        }
        return null;
      }),
    );

    final title = selected == null
        ? l10n.translationServiceNotSelected
        : translationServiceName(l10n, plugins, selected);
    final String? subtitle = !ready
        ? l10n.lyricsTranslationModalPluginsLoading
        : unset
        ? l10n.lyricsTranslationModalServiceUnset
        : null;
    final titleColor = unset ? colors.error : colors.onSurface;
    final subtitleColor = unset ? colors.error : colors.onSurfaceVariant;

    return Semantics(
      container: true,
      button: true,
      enabled: ready,
      child: Opacity(
        opacity: ready ? 1 : 0.45,
        child: InkWell(
          onTap: ready
              ? () => unawaited(openServicePicker(context, ref))
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
              child: Row(
                children: [
                  if (unset)
                    Icon(AppIcons.errorOutline, color: colors.error)
                  else
                    // Same 24 px box as the error icon so the text stays aligned.
                    PluginIcon(record: record, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeText(
                          text: title,
                          startDelay: _serviceMarqueeDelay,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null)
                          MarqueeText(
                            text: subtitle,
                            startDelay: _serviceMarqueeDelay,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (record?.kind == PluginKind.aiTranslate) ...[
                    const SizedBox(width: 8),
                    const TranslationAiBadge(),
                  ],
                  const SizedBox(width: 16),
                  Icon(AppIcons.chevronRight, color: colors.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
