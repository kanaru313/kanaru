import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/translation_language_name.dart';
import '../../../../../shared/translation_plugin_routes.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../now_playing/now_playing_open_provider.dart';
import '../lyrics_translation_labels.dart';
import '../translation_failure_actions.dart';
import 'translation_modal_navigation.dart';

/// Compact status block below the service row in the translation modal, shown
/// only when there is progress, a failure, or a same-language note to report.
class TranslationStatusLine extends ConsumerWidget {
  const TranslationStatusLine({
    super.key,
    required this.state,
    required this.appLang,
    required this.onRetranslate,
  });

  final LyricsTranslationState state;
  final String appLang;
  final VoidCallback onRetranslate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cancel = MaterialLocalizations.of(context).cancelButtonLabel;
    final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
    final selected = ref.watch(translationServiceChoicesProvider).selected;

    return switch (state) {
      TranslationLoading() => _statusRow(
        theme,
        l10n.lyricsTranslationLoading,
        actionLabel: cancel,
        onAction: ref.read(settingsProvider.notifier).toggleLyricsTranslation,
      ),
      TranslationReady(refreshing: true) ||
      TranslationSameLanguage(refreshing: true) => _statusRow(
        theme,
        l10n.lyricsTranslationModalRetranslating,
        actionLabel: cancel,
        onAction: controller.cancelRetranslate,
      ),
      TranslationFailed(service: final s, kind: final k) => _failureCard(
        context,
        ref,
        s,
        k,
      ),
      TranslationReady(retranslateFailure: final k?, service: final s) =>
        _failureCard(context, ref, selected ?? s, k, true),
      TranslationSameLanguage(retranslateFailure: final k?, service: final s) =>
        _failureCard(context, ref, selected ?? s, k, true),
      TranslationSameLanguage(
        :final info,
        :final service,
        :final fromOtherService,
      ) =>
        _statusRow(
          theme,
          _sameLanguageText(context, ref, info, service, fromOtherService),
          leading: Icon(
            AppIcons.success,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  String _sameLanguageText(
    BuildContext context,
    WidgetRef ref,
    TranslationTargetInfo info,
    TranslationServiceId service,
    bool fromOtherService,
  ) {
    final l10n = context.l10n;
    final language = languageNameInSentence(
      l10n,
      translationLanguageName(l10n, info.effective),
    );
    if (!fromOtherService) return l10n.lyricsTranslationSameLanguage(language);
    final infos = ref.watch(translationPluginInfosProvider);
    return l10n.lyricsTranslationSameLanguageFrom(
      language,
      translationServiceName(l10n, infos, service),
    );
  }

  Widget _statusRow(
    ThemeData theme,
    String text, {
    Widget leading = const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: style)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }

  void _openPlugin(BuildContext context, TranslationServiceId service) {
    final router = GoRouter.maybeOf(context);
    final scope = ProviderScope.containerOf(context, listen: false);
    closeTranslationModalStack(context);
    scope.read(nowPlayingOpenProvider.notifier).close();
    router?.go(translationPluginRoute(service.value));
  }

  Widget _failureCard(
    BuildContext context,
    WidgetRef ref,
    TranslationServiceId service,
    TranslationFailureKind kind, [
    bool retranslate = false,
  ]) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onColor = colors.onErrorContainer;
    final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
    final infos = ref.watch(translationPluginInfosProvider);
    final name = translationServiceName(l10n, infos, service);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: onColor,
      fontWeight: FontWeight.w500,
    );
    final reasonStyle = theme.textTheme.bodySmall?.copyWith(color: onColor);
    final configLabel = kind == TranslationFailureKind.needsConfig
        ? l10n.pluginOpenConfig
        : l10n.lyricsTranslationBannerOpenPlugin;
    final retry = retranslate ? onRetranslate : controller.retry;
    final keepOld = controller.dismissRetranslateFailure;
    TextButton btn(String label, VoidCallback onTap) =>
        TextButton(onPressed: onTap, child: Text(label));
    final actions = <Widget>[
      if (failureOpensPluginSettings(kind))
        btn(configLabel, () => _openPlugin(context, service)),
      if (failureCanRetry(kind)) btn(l10n.lyricsTranslationRetry, retry),
      if (retranslate) btn(l10n.lyricsTranslationBannerKeepOld, keepOld),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.errorOutline, color: colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lyricsTranslationModalServiceError(name),
                      style: titleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      translationFailureMessage(l10n, kind),
                      style: reasonStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(spacing: 4, children: actions),
            ),
        ],
      ),
    );
  }
}
