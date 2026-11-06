import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import 'translation_ai_option_label.dart';
import 'translation_ai_tune_modal.dart';

/// Pause before an overflowing subtitle starts scrolling.
const Duration _rowMarqueeDelay = Duration(milliseconds: 300);

/// The "AI tuning · <style>" row under the service row of an `ai-translate`
/// plugin. A tap opens the tune modal for the song with lyrics hash [hash].
class TranslationAiTuneRow extends ConsumerWidget {
  const TranslationAiTuneRow({
    super.key,
    required this.service,
    required this.hash,
    required this.appLang,
    required this.onRetranslate,
  });

  final TranslationServiceId service;
  final String hash;
  final String appLang;

  /// Called when the tune modal closes asking for a retranslation.
  final VoidCallback onRetranslate;

  Future<void> _open(BuildContext context) async {
    final retranslate = await openAiTuneModal(
      context,
      service: service,
      hash: hash,
      appLang: appLang,
    );
    if (retranslate == true && context.mounted) onRetranslate();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final values = ref.watch(aiTuneValuesProvider(service)).value;
    final subtitle = values == null
        ? null
        : aiOptionLabel(
            l10n,
            pluginEffectiveField(values.tune.style, values.stored),
            values.stored,
          ).title;
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: () => unawaited(_open(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
            child: Row(
              children: [
                Icon(AppIcons.aiTune, color: colors.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.translationAiTuneRow,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (subtitle != null)
                        MarqueeText(
                          text: subtitle,
                          startDelay: _rowMarqueeDelay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(AppIcons.chevronRight, color: colors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
