import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../core/lyrics_translation/translation_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_plugin_routes.dart';
import '../../now_playing/now_playing_open_provider.dart';
import 'lyrics_translation_labels.dart';
import 'translation_failure_actions.dart';

/// Widest the banner grows.
const _bannerMaxWidth = 520.0;

/// Small banner at the top of the lyrics after a failed translation: why, and
/// the way out: open the settings or, where it can help, retry. The
/// lyrics keep playing and scrolling under it. With [keepsOld] a retranslate
/// failed while an older version stays shown: Retry translates again and
/// "Keep the old version" hides the banner.
class LyricsTranslationBanner extends ConsumerWidget {
  const LyricsTranslationBanner({
    super.key,
    required this.service,
    required this.kind,
    required this.appLang,
    this.keepsOld = false,
  });

  /// The service that failed (the selected one), whose page the settings
  /// button opens.
  final TranslationServiceId service;
  final TranslationFailureKind kind;
  final bool keepsOld;

  /// Picks the controller (the app's language code).
  final String appLang;

  /// Closes Now Playing and opens the page of the plugin that failed, where
  /// its key or settings live.
  void _openKeySettings(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    ref.read(nowPlayingOpenProvider.notifier).close();
    router?.go(translationPluginRoute(service.value));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reason = switch (kind) {
      TranslationFailureKind.noKey => l10n.lyricsTranslationBannerNoKey,
      TranslationFailureKind.badKey => l10n.lyricsTranslationBannerBadKey,
      _ => translationFailureMessage(l10n, kind),
    };
    final message = keepsOld
        ? '${l10n.lyricsTranslationRetranslateFailed}\n$reason'
        : reason;
    final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
    final opensSettings = failureOpensPluginSettings(kind);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _bannerMaxWidth),
          child: Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      children: [
                        if (opensSettings)
                          TextButton(
                            onPressed: () => _openKeySettings(context, ref),
                            child: Text(
                              kind == TranslationFailureKind.needsConfig
                                  ? l10n.pluginOpenConfig
                                  : l10n.lyricsTranslationBannerOpenPlugin,
                            ),
                          ),
                        if (failureCanRetry(kind))
                          TextButton(
                            onPressed: keepsOld
                                ? controller.retranslate
                                : controller.retry,
                            child: Text(l10n.lyricsTranslationRetry),
                          ),
                        if (keepsOld)
                          TextButton(
                            onPressed: controller.dismissRetranslateFailure,
                            child: Text(l10n.lyricsTranslationBannerKeepOld),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
