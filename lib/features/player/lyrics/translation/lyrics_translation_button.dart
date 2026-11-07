import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/translation_service_name.dart';
import '../../now_playing/now_playing_translation_toggle.dart';
import '../../playback_controls.dart';
import 'lyrics_translation_failed_dot.dart';
import 'lyrics_translation_labels.dart';
import 'lyrics_translation_pill.dart';
import 'modal/lyrics_translation_modal.dart';

/// Header button that opens the lyrics translation modal on primary press and
/// toggles translation on secondary tap. Off, it is a plain icon; on, it is the
/// primary colour on a raised background; while translating or retranslating a
/// ring turns around it; after a failure an error dot sits at its corner. With
/// translated lyrics and room for a label it is a pill with the plugin icon and
/// target language.
class LyricsTranslationButton extends ConsumerStatefulWidget {
  const LyricsTranslationButton({
    super.key,
    this.onModalChanged,
    this.modalOpener,
    this.enabled = true,
    this.maxLabelWidth,
  });

  final ValueChanged<bool>? onModalChanged;
  final ValueNotifier<bool Function()?>? modalOpener;
  final bool enabled;
  final double? maxLabelWidth;

  @override
  ConsumerState<LyricsTranslationButton> createState() =>
      _LyricsTranslationButtonState();
}

class _LyricsTranslationButtonState
    extends ConsumerState<LyricsTranslationButton> {
  bool _open = false;
  bool _usable = false;

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onModalChanged?.call(open);
  }

  @override
  void didUpdateWidget(LyricsTranslationButton old) {
    super.didUpdateWidget(old);
    if (old.modalOpener == widget.modalOpener) return;
    final previous = old.modalOpener;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous?.value == _openModal) previous?.value = null;
    });
  }

  void _syncOpener() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final opener = widget.modalOpener;
    if (!mounted || opener == null) return;
    if (!_usable && opener.value == _openModal) {
      opener.value = null;
    } else if (_usable && opener.value != _openModal) {
      opener.value = _openModal;
    }
  });

  @override
  void dispose() {
    final opener = widget.modalOpener;
    if (opener != null && opener.value == _openModal) opener.value = null;
    _setOpen(false);
    super.dispose();
  }

  bool _openModal() {
    if (_open || !_usable) return false;
    unawaited(_runModal());
    return true;
  }

  Future<void> _runModal() async {
    _setOpen(true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final appLang = Localizations.localeOf(context).languageCode;
    try {
      await showLyricsTranslationModal(
        context,
        appLang: appLang,
        messenger: messenger,
      );
    } finally {
      // The modal route puts focus back where it was when it closes.
      if (mounted) _setOpen(false);
    }
  }

  void _onSecondaryTap() => quickToggleLyricsTranslation(
    context,
    ref,
    hasLyrics: widget.enabled,
    openModal: _openModal,
    // The button watches this state, so reading it here starts nothing new.
    songService: translationInfoOf(
      ref.read(
        lyricsTranslationProvider(Localizations.localeOf(context).languageCode),
      ),
    )?.choice?.service,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final appLang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(lyricsTranslationProvider(appLang));
    final plugins = ref.watch(translationPluginInfosProvider);
    final active = translationIsActive(state);
    final usable = widget.enabled && state is! TranslationUnavailable;
    _usable = usable;
    if (widget.modalOpener != null) _syncOpener();

    final tooltip =
        '${translationButtonTooltip(l10n, state, (id) => translationServiceName(l10n, plugins, id))}'
        '\n${l10n.lyricsTranslationButtonHint}';
    final failed = translationShowsFailure(state);
    final busy =
        state is TranslationLoading ||
        (state is TranslationReady && state.refreshing) ||
        (state is TranslationSameLanguage && state.refreshing);
    final room = widget.maxLabelWidth ?? 0;

    final child =
        state is TranslationReady && room >= lyricsTranslationMinLabelWidth
        ? Stack(
            alignment: Alignment.center,
            children: [
              LyricsTranslationPill(
                state: state,
                tooltip: tooltip,
                maxLabelWidth: room,
                busy: busy,
                onPressed: usable ? _openModal : null,
              ),
              if (failed) const LyricsTranslationFailedDot(top: 2, right: 4),
            ],
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(AppIcons.lyricsTranslateOutlined),
                selectedIcon: const Icon(AppIcons.lyricsTranslate),
                isSelected: active,
                iconSize: playerIconSize,
                style: active
                    ? IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.primary,
                      )
                    : null,
                tooltip: tooltip,
                onPressed: usable ? _openModal : null,
              ),
              if (busy)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (failed) const LyricsTranslationFailedDot(top: 8, right: 8),
            ],
          );

    return GestureDetector(
      onSecondaryTap: usable ? _onSecondaryTap : null,
      child: child,
    );
  }
}
