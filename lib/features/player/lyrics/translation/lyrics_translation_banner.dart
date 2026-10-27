import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_notice_dialog.dart';
import 'lyrics_translation_labels.dart';

/// Widest the banner grows.
const _bannerMaxWidth = 520.0;

/// Whether the failure is about the DeepL key, which Retry cannot fix.
bool _isKeyError(TranslationFailureKind kind) =>
    kind == TranslationFailureKind.noKey ||
    kind == TranslationFailureKind.badKey;

/// Whether trying again may help. Too-long lyrics and an unsupported
/// language fail the same way every time.
bool _canRetry(TranslationFailureKind kind) =>
    !_isKeyError(kind) &&
    kind != TranslationFailureKind.tooLong &&
    kind != TranslationFailureKind.unsupportedLanguage;

/// Small banner at the top of the lyrics after a failed translation: why, and
/// the ways out: use the other service and, where it can help, retry. The
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

  Future<void> _useOther(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
    // False: the other service's notice is not accepted yet; ask first.
    if (!controller.useOtherService()) {
      await enableTranslationWithNotice(context, ref, state.service.other);
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
                        TextButton(
                          onPressed: () => _useOther(context, ref),
                          child: Text(
                            l10n.lyricsTranslationUseService(
                              translationServiceName(state.service.other),
                            ),
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
