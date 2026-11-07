import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../lyrics/source/lyrics_source_button.dart';
import '../lyrics/translation/lyrics_translation_button.dart';
import '../lyrics/translation/lyrics_translation_pill.dart';

/// Air before the first header button.
const nowPlayingHeaderLeftInset = 14.0;

/// Gap between the left buttons that close or switch the view and those that
/// act on the song.
const nowPlayingHeaderLeftGap = 16.0;

/// Air between two header buttons. With the 2 px a round button's 48 px slot
/// leaves around its circle (and a pill's matching margin), every button
/// reads 6 px from the next. Kept small so every button fits a 720 px window
/// beside the window buttons.
const nowPlayingHeaderButtonGap = 2.0;

/// Room the right group needs for its four buttons and the gaps between them.
const nowPlayingHeaderRightButtonsWidth =
    4 * 48.0 + 3 * nowPlayingHeaderButtonGap;

/// Room the sleep timer pill needs beyond its round button: the label (56)
/// and what the pill's margin, padding and icon add to the 48 px button (16).
const nowPlayingHeaderSleepLabelWidth = 72.0;

/// Gap, divider line and gap between the right buttons and the window
/// buttons.
const nowPlayingHeaderSeparatorWidth = 25.0;

/// Width of one round header button.
const _buttonWidth = 48.0;

/// Room the label of the translate button may take in a header [width] wide:
/// what is left after every other button, the sleep timer label's reserve and
/// the window buttons' divider, plus the round button the pill replaces, minus
/// the pill's own margin, padding and icon. Zero or less means
/// no room for a label, and it is zero while the translation is not a pill
/// ([translatePill]).
@visibleForTesting
({double translate}) nowPlayingPillLabelRooms({
  required double width,
  required bool hasModeButton,
  required bool hasWindowButtons,
  required bool translatePill,
}) {
  // Close, [mode], favorite, playlist, lyrics, translate.
  final left =
      nowPlayingHeaderLeftInset +
      (hasModeButton ? 6 : 5) * _buttonWidth +
      nowPlayingHeaderLeftGap +
      (hasModeButton ? 4 : 3) * nowPlayingHeaderButtonGap;
  final right =
      nowPlayingHeaderRightButtonsWidth +
      nowPlayingHeaderSleepLabelWidth +
      (hasWindowButtons ? nowPlayingHeaderSeparatorWidth : 0);
  if (!translatePill) return (translate: 0);
  const translateSpare = _buttonWidth - lyricsTranslationPillChrome;
  return (translate: width - left - right + translateSpare);
}

/// The lyrics button followed by the translate button, which may grow into a
/// pill with the room [nowPlayingPillLabelRooms] gives it. Only whether the
/// translation is a pill is watched here, so the pair rebuilds when that
/// flips and not on every translation change.
class NowPlayingLyricsPills extends ConsumerWidget {
  const NowPlayingLyricsPills({
    super.key,
    required this.width,
    required this.hasModeButton,
    required this.hasWindowButtons,
    required this.translateEnabled,
    required this.onTranslateModalChanged,
    required this.onLyricsModalChanged,
    required this.lyricsModalOpener,
    this.translationModalOpener,
  });

  /// The header's width.
  final double width;
  final bool hasModeButton;
  final bool hasWindowButtons;
  final bool translateEnabled;
  final ValueChanged<bool> onTranslateModalChanged;
  final ValueChanged<bool> onLyricsModalChanged;
  final ValueNotifier<bool Function()?>? lyricsModalOpener;
  final ValueNotifier<bool Function()?>? translationModalOpener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLang = Localizations.localeOf(context).languageCode;
    final translatePill = ref.watch(
      lyricsTranslationProvider(appLang).select((s) => s is TranslationReady),
    );
    final rooms = nowPlayingPillLabelRooms(
      width: width,
      hasModeButton: hasModeButton,
      hasWindowButtons: hasWindowButtons,
      translatePill: translatePill,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: nowPlayingHeaderButtonGap),
        LyricsSourceButton(
          modalOpener: lyricsModalOpener,
          onModalChanged: onLyricsModalChanged,
        ),
        const SizedBox(width: nowPlayingHeaderButtonGap),
        LyricsTranslationButton(
          enabled: translateEnabled,
          maxLabelWidth: rooms.translate,
          modalOpener: translationModalOpener,
          onModalChanged: onTranslateModalChanged,
        ),
      ],
    );
  }
}
