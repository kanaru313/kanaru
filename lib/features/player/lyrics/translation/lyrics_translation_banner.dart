import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../core/lyrics_translation/translation_service.dart';
import '../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../core/settings/settings_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/settings_routes.dart';
import '../../../../shared/translation_notice_dialog.dart';
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
/// missing, rejected, or cannot be read from a locked key store.
bool _isPluginKeyIssue(TranslationFailureKind kind) =>
    _isKeyError(kind) || kind == TranslationFailureKind.keyStoreLocked;

/// Whether trying again may help. Too-long lyrics and an unsupported
/// language fail the same way every time.
bool _canRetry(TranslationFailureKind kind) =>
    !_isKeyError(kind) &&
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
  /// its key is set; the translation settings for a built-in service.
  void _openKeySettings(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    ref.read(nowPlayingOpenProvider.notifier).close();
    router?.go(
      state.service.isPlugin
          ? translationPluginRoute(state.service.value)
          : settingsFocusLocation(SettingsAnchor.playbackTranslation),
    );
  }

  /// Switches to Google. Google not accepted yet: its notice comes first and
  /// Cancel leaves the plugin selected.
  Future<void> _useGoogle(BuildContext context, WidgetRef ref) async {
    const google = TranslationServiceId.google;
    final prefs = ref.read(settingsProvider).translation;
    if (needsNoticeFor(prefs, google)) {
      await enableTranslationWithNotice(context, ref, google);
    } else {
      ref.read(lyricsTranslationProvider(appLang).notifier).useGoogle();
    }
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
    final isPlugin = state.service.isPlugin;
    final opensSettings = isPlugin
        ? _isPluginKeyIssue(kind)
        : _isKeyError(kind);
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
                              isPlugin
                                  ? l10n.lyricsTranslationBannerOpenPlugin
                                  : l10n.lyricsTranslationBannerOpenKey,
                            ),
                          ),
                        if (_canRetry(kind))
                          TextButton(
                            onPressed: controller.retry,
                            child: Text(l10n.lyricsTranslationRetry),
                          ),
                        // Google is the way out of a plugin that fails; a
                        // Google failure has no service to switch to.
                        if (isPlugin)
                          TextButton(
                            onPressed: () => _useGoogle(context, ref),
                            child: Text(l10n.lyricsTranslationBannerUseGoogle),
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
