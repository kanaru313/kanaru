import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import '../lyrics_translation_labels.dart';
import 'translation_action_bar.dart';
import 'translation_ai_tune_changes.dart';
import 'translation_background_retranslate.dart';
import 'translation_language_row.dart';
import 'translation_modal_header.dart';
import 'translation_modal_navigation.dart';
import 'translation_preview_card.dart';
import 'translation_service_section.dart';
import 'translation_status_line.dart';

/// Opens the lyrics translation modal at depth 0 on the root navigator (a
/// 400 px centered dialog at or above 600 px, or a bottom sheet below).
///
/// [messenger] is the [ScaffoldMessengerState] of the opener (Now Playing), so
/// a background retranslate that finishes after the modal closes shows its
/// snackbar on the screen behind; when omitted, `ScaffoldMessenger.maybeOf` of
/// [context] is captured before the modal route is pushed.
Future<void> showLyricsTranslationModal(
  BuildContext context, {
  required String appLang,
  ScaffoldMessengerState? messenger,
}) {
  final effectiveMessenger = messenger ?? ScaffoldMessenger.maybeOf(context);
  return showLayeredModal<void>(
    context,
    semanticLabel: context.l10n.lyricsTranslationButton,
    builder: (_) =>
        LyricsTranslationModal(appLang: appLang, messenger: effectiveMessenger),
  );
}

/// Parent modal for lyrics translation: the song header with settings and
/// close buttons, the live lyric line preview card, the "Translation" section
/// (language row with switch, service row or empty-plugins card, and status
/// line), and the optional bottom [TranslationActionBar] outside the scroll
/// view.
///
/// Section order in the scrolling body:
/// 1. Preview card ([TranslationPreviewCard]).
/// 2. Translation section ([TranslationLanguageRow],
///    [TranslationServiceSection], [TranslationStatusLine]).
/// 3. Transliteration section (reserved after Translation, not rendered yet).
///
/// When [lyricsTranslationProvider] becomes [TranslationUnavailable] while the
/// modal is open, the entire modal stack (any open child picker or consent
/// dialog plus this parent modal) closes automatically.
class LyricsTranslationModal extends ConsumerStatefulWidget {
  const LyricsTranslationModal({
    super.key,
    required this.appLang,
    this.messenger,
  });

  final String appLang;
  final ScaffoldMessengerState? messenger;

  @override
  ConsumerState<LyricsTranslationModal> createState() =>
      _LyricsTranslationModalState();
}

class _LyricsTranslationModalState
    extends ConsumerState<LyricsTranslationModal> {
  bool _closing = false;

  // The lyrics hash the modal opened on; another song closes the stack.
  String? _openedHash;

  void _scheduleCloseStack() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      closeTranslationModalStack(context);
    });
  }

  void _retranslate() {
    unawaited(
      startBackgroundRetranslate(
        context,
        ref,
        appLang: widget.appLang,
        messenger: widget.messenger,
      ),
    );
  }

  Widget? _buildActionBar(BuildContext context, LyricsTranslationState state) {
    final service = switch (state) {
      TranslationReady(
        :final service,
        fromOtherService: true,
        refreshing: false,
        retranslateFailure: null,
      ) ||
      TranslationSameLanguage(
        :final service,
        fromOtherService: true,
        refreshing: false,
        retranslateFailure: null,
      ) => service,
      _ => null,
    };
    if (service == null) return _buildChangedBar(context, state);
    final selected = ref.watch(
      translationServiceChoicesProvider.select((c) => c.selected),
    );
    if (selected == null) return null;
    final l10n = context.l10n;
    final plugins = ref.watch(translationPluginInfosProvider);
    final shownName = translationServiceName(l10n, plugins, service);
    final selectedName = translationServiceName(l10n, plugins, selected);
    return TranslationActionBar(
      text: l10n.lyricsTranslationModalShowingOther(shownName),
      actionLabel: l10n.lyricsTranslationModalTranslateWith(selectedName),
      onPressed: _retranslate,
    );
  }

  // The AI settings differ from the version on screen: offer to translate
  // again. Nothing is sent until the user asks.
  Widget? _buildChangedBar(BuildContext context, LyricsTranslationState state) {
    final changes = watchAiTuneChanges(ref, state, _openedHash);
    // A failed retranslation has its error card with Retry.
    if (changes.isEmpty ||
        state is! TranslationReady ||
        state.retranslateFailure != null) {
      return null;
    }
    final values = ref.watch(aiTuneValuesProvider(state.service)).value;
    if (values == null) return null;
    final l10n = context.l10n;
    return TranslationActionBar(
      text: l10n.translationAiTuneChanged(
        aiTuneChangesText(l10n, values.tune, values.stored, changes),
      ),
      actionLabel: l10n.lyricsTranslationRetranslate,
      onPressed: _retranslate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lyricsTranslationProvider(widget.appLang));
    final info = translationInfoOf(state);
    _openedHash ??= info?.hash;
    if (info == null || info.hash != _openedHash) {
      _scheduleCloseStack();
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    return LayeredModalBody(
      header: const TranslationModalHeader(),
      footer: _buildActionBar(context, state),
      children: [
        TranslationPreviewCard(state: state, onRetranslate: _retranslate),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Semantics(
            header: true,
            child: Text(
              l10n.lyricsTranslationModalSection,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        TranslationLanguageRow(
          state: state,
          info: info,
          appLang: widget.appLang,
        ),
        TranslationServiceSection(
          state: state,
          appLang: widget.appLang,
          onRetranslate: _retranslate,
        ),
        TranslationStatusLine(
          state: state,
          appLang: widget.appLang,
          onRetranslate: _retranslate,
        ),
      ],
    );
  }
}
