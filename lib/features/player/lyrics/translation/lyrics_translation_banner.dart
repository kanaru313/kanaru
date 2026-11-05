import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_plugin_routes.dart';
import '../../now_playing/now_playing_open_provider.dart';
import 'lyrics_translation_labels.dart';

/// Widest the banner grows.
const _bannerMaxWidth = 520.0;

/// Whether the failure is about the service key, which Retry cannot fix.
bool _isKeyError(TranslationFailureKind kind) =>
    kind == TranslationFailureKind.noKey ||
    kind == TranslationFailureKind.badKey;

/// Whether the plugin's settings page can fix the failure: its key is
/// missing, rejected, or cannot be read from a locked key store, or a
/// required setting is empty.
bool _opensPluginSettings(TranslationFailureKind kind) =>
    _isKeyError(kind) ||
    kind == TranslationFailureKind.keyStoreLocked ||
    kind == TranslationFailureKind.needsConfig;

/// Whether trying again may help. Too-long lyrics and an unsupported
/// language fail the same way every time.
bool _canRetry(TranslationFailureKind kind) =>
    !_isKeyError(kind) &&
    kind != TranslationFailureKind.needsConfig &&
    kind != TranslationFailureKind.tooLong &&
    kind != TranslationFailureKind.unsupportedLanguage;

/// Small banner at the top of the lyrics after a failed translation: why, and
/// the way out: open the settings or, where it can help, retry. The
/// lyrics keep playing and scrolling under it.
class LyricsTranslationBanner extends ConsumerWidget {
  const LyricsTranslationBanner({
    super.key,
    required this.state,
    required this.appLang,
  });

  final TranslationFailed state;

  /// Picks the controller (the app's language code).
  final String appLang;

  /// Closes Now Playing and opens the page of the plugin that failed, where
  /// its key or settings live.
  void _openKeySettings(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    ref.read(nowPlayingOpenProvider.notifier).close();
    router?.go(translationPluginRoute(state.service.value));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kind = state.kind;
    final message = switch (kind) {
      TranslationFailureKind.noKey => l10n.lyricsTranslationBannerNoKey,
      TranslationFailureKind.badKey => l10n.lyricsTranslationBannerBadKey,
      _ => translationFailureMessage(l10n, kind),
    };
    final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
    final opensSettings = _opensPluginSettings(kind);
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
                        if (_canRetry(kind))
                          TextButton(
                            onPressed: controller.retry,
                            child: Text(l10n.lyricsTranslationRetry),
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
