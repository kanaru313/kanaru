import 'package:material_ui/material_ui.dart';

import '../playback_controls.dart';
import '../repeat/repeat_button.dart';
import '../sleep_timer/sleep_timer_button.dart';
import '../volume_button.dart';
import 'now_playing_actions.dart';
import 'now_playing_header_pills.dart';
import 'now_playing_title_bar.dart';

/// Height of the header strip across the top of Now Playing.
const nowPlayingHeaderHeight = 64.0;

/// Wide Now Playing's header: close and the song actions on the left; shuffle,
/// repeat, sleep timer and volume on the right. The window buttons, when the
/// app draws them, come after it (see [NowPlayingTitleBar.wrapHeader]).
///
/// [floatingOpen] is set to whether one of the things that float outside the
/// header is open: the volume popup, or the repeat, sleep timer, translation
/// or lyrics source menu. Whoever hides the header on inactivity listens to it to
/// keep the header shown meanwhile.
class NowPlayingHeader extends StatefulWidget {
  const NowPlayingHeader({
    super.key,
    required this.onClose,
    required this.excludeFromDrag,
    required this.floatingOpen,
    this.hasWindowButtons = false,
    this.modeButton,
    this.showTranslate = false,
    this.translateEnabled = true,
    this.sourceMenuOpener,
  });

  final VoidCallback onClose;

  /// Wraps each group of buttons so pressing them never drags the window.
  final NowPlayingDragExclusion excludeFromDrag;

  /// Written by the header, see the class comment.
  final ValueNotifier<bool> floatingOpen;

  /// Whether the window buttons follow: the right group then ends in a
  /// divider, so a stray click does not land on close.
  final bool hasWindowButtons;

  /// Sits right of the close button; `null` leaves the spot empty.
  final Widget? modeButton;

  /// Whether the lyrics translation and source buttons follow the playlist
  /// button.
  final bool showTranslate;

  /// False greys the translation button out, for a song without lyrics.
  final bool translateEnabled;

  /// Receives the callback that opens the lyrics source menu while its
  /// button (which follows the translation button) is in the header.
  final ValueNotifier<bool Function()?>? sourceMenuOpener;

  @override
  State<NowPlayingHeader> createState() => _NowPlayingHeaderState();
}

class _NowPlayingHeaderState extends State<NowPlayingHeader> {
  bool _volumeOpen = false;
  bool _sleepOpen = false;
  bool _repeatOpen = false;
  bool _translateOpen = false;
  bool _sourceOpen = false;

  void _report() => widget.floatingOpen.value =
      _volumeOpen || _sleepOpen || _repeatOpen || _translateOpen || _sourceOpen;

  @override
  void dispose() {
    // The popup and the menu leave with the header: give the pin back.
    _volumeOpen = false;
    _sleepOpen = false;
    _repeatOpen = false;
    _translateOpen = false;
    _sourceOpen = false;
    _report();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exclude = widget.excludeFromDrag;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: nowPlayingHeaderHeight,
      child: LayoutBuilder(
        builder: (context, bounds) => Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: nowPlayingHeaderLeftInset),
              child: exclude(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NowPlayingCloseButton(onPressed: widget.onClose),
                    ?widget.modeButton,
                    const SizedBox(width: nowPlayingHeaderLeftGap),
                    const NowPlayingFavoriteButton(),
                    const NowPlayingPlaylistButton(),
                    if (widget.showTranslate)
                      NowPlayingLyricsPills(
                        width: bounds.maxWidth,
                        hasModeButton: widget.modeButton != null,
                        hasWindowButtons: widget.hasWindowButtons,
                        translateEnabled: widget.translateEnabled,
                        sourceMenuOpener: widget.sourceMenuOpener,
                        onTranslateMenuChanged: (open) {
                          _translateOpen = open;
                          _report();
                        },
                        onSourceMenuChanged: (open) {
                          _sourceOpen = open;
                          _report();
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, side) {
                  final separator = widget.hasWindowButtons
                      ? nowPlayingHeaderSeparatorWidth
                      : 0.0;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: exclude(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ShuffleButton(),
                          RepeatButton(
                            onMenuChanged: (open) {
                              _repeatOpen = open;
                              _report();
                            },
                          ),
                          Flexible(
                            child: SleepTimerButton(
                              pill: true,
                              showLabel:
                                  side.maxWidth - separator >=
                                  nowPlayingHeaderRightButtonsWidth +
                                      nowPlayingHeaderSleepLabelWidth,
                              onDialogChanged: (open) {
                                _sleepOpen = open;
                                _report();
                              },
                            ),
                          ),
                          VolumeButton(
                            popupBelow: true,
                            onPopupChanged: (open) {
                              _volumeOpen = open;
                              _report();
                            },
                          ),
                          if (widget.hasWindowButtons)
                            SizedBox(
                              width: nowPlayingHeaderSeparatorWidth,
                              height: 24,
                              child: Center(
                                child: VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: colors.outlineVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
