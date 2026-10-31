import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../lyrics/source/lyrics_source_button.dart';
import '../lyrics/translation/lyrics_translation_button.dart';
import '../lyrics/translation/lyrics_translation_pill.dart';

/// Air before the first header button.
const nowPlayingHeaderLeftInset = 30.0;

/// Gap between the left buttons that close or switch the view and those that
/// act on the song.
const nowPlayingHeaderLeftGap = 16.0;

/// Room the right group needs for its four buttons.
const nowPlayingHeaderRightButtonsWidth = 4 * 48.0;

/// Room the sleep timer pill needs beyond its round button: the label (56)
/// and what the pill's padding and icon add to the 48 px button (12).
const nowPlayingHeaderSleepLabelWidth = 68.0;

/// Gap, divider line and gap between the right buttons and the window
/// buttons.
const nowPlayingHeaderSeparatorWidth = 25.0;

/// Width of one round header button.
const _buttonWidth = 48.0;

/// Air after the lyrics source pill, so it reads apart from the translate
/// button beside it, whether that is a pill or a tinted round icon.
const nowPlayingPillGap = 8.0;

/// Room the labels of the two lyrics buttons (lyrics source, then
/// translation) may take in a header [width] wide: what is left after every other
/// button, the sleep timer label's reserve and the window buttons' divider,
/// plus the round buttons the pills replace, minus each pill's own padding
/// and icon. Zero or less means no room for a label.
///
/// The [nowPlayingPillGap] after the source pill comes off first. The room
/// is split in two only when the translation is a pill ([translatePill]);
/// otherwise the source pill gets all of it and the translate button stays
/// an icon.
@visibleForTesting
({double source, double translate}) nowPlayingPillLabelRooms({
  required double width,
  required bool hasModeButton,
  required bool hasWindowButtons,
  required bool translatePill,
}) {
  // Close, [mode], favorite, playlist, translate, source.
  final left =
      nowPlayingHeaderLeftInset +
      (hasModeButton ? 6 : 5) * _buttonWidth +
      nowPlayingHeaderLeftGap;
  final right =
      nowPlayingHeaderRightButtonsWidth +
      nowPlayingHeaderSleepLabelWidth +
      (hasWindowButtons ? nowPlayingHeaderSeparatorWidth : 0);
  final free = width - left - right - nowPlayingPillGap;
  const spare = _buttonWidth - lyricsTranslationPillChrome;
  if (!translatePill) return (source: free + spare, translate: 0);
  final half = (free + 2 * spare) / 2;
  return (source: half, translate: half);
}

/// The lyrics source button followed by the translate button, sharing the
/// room [nowPlayingPillLabelRooms] gives them. Only whether the translation
/// is a pill is watched here, so the pair rebuilds when that flips and not
/// on every translation change. Lyrics turned off for the song keep the
/// source button a round icon.
class NowPlayingLyricsPills extends ConsumerWidget {
  const NowPlayingLyricsPills({
    super.key,
    required this.width,
    required this.hasModeButton,
    required this.hasWindowButtons,
    required this.translateEnabled,
    required this.onTranslateMenuChanged,
    required this.onSourceMenuChanged,
    required this.sourceMenuOpener,
  });

  /// The header's width.
  final double width;
  final bool hasModeButton;
  final bool hasWindowButtons;
  final bool translateEnabled;
  final ValueChanged<bool> onTranslateMenuChanged;
  final ValueChanged<bool> onSourceMenuChanged;
  final ValueNotifier<bool Function()?>? sourceMenuOpener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLang = Localizations.localeOf(context).languageCode;
    final translatePill = ref.watch(
      lyricsTranslationProvider(appLang).select((s) => s is TranslationReady),
    );
    // Lyrics turned off for the song: the source button is only its icon.
    final sourceOff = ref.watch(
      playingLyricsSourceProvider.select(
        (s) => switch (s?.status) {
          LyricsNone(reason: LyricsNoneReason.off) => true,
          _ => false,
        },
      ),
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
        LyricsSourceButton(
          maxLabelWidth: sourceOff ? 0 : rooms.source,
          menuOpener: sourceMenuOpener,
          onMenuChanged: onSourceMenuChanged,
        ),
        // Only after a source pill: a source squeezed back to its round
        // icon keeps the round buttons' usual spacing.
        if (!sourceOff && rooms.source >= lyricsTranslationMinLabelWidth)
          const SizedBox(width: nowPlayingPillGap),
        LyricsTranslationButton(
          enabled: translateEnabled,
          maxLabelWidth: rooms.translate,
          onMenuChanged: onTranslateMenuChanged,
        ),
      ],
    );
  }
}
