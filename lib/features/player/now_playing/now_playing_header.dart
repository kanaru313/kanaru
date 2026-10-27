import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';
import '../repeat/repeat_button.dart';
import '../sleep_timer/sleep_timer_button.dart';
import '../volume_button.dart';
import 'now_playing_actions.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_view_mode.dart';

/// Height of the header strip across the top of Now Playing.
const nowPlayingHeaderHeight = 64.0;

/// Air before the first button.
const _leftInset = 30.0;

/// Gap between the left buttons that close or switch the view and those that
/// act on the song.
const _leftGap = 16.0;

/// Room the right group needs for its four buttons.
const _rightButtonsWidth = 4 * 48.0;

/// Room the sleep timer label needs beside its button.
const _sleepLabelWidth = 56.0;

/// Gap, divider line and gap between the right buttons and the window
/// buttons.
const _rightSeparatorWidth = 25.0;

/// Wide Now Playing's header: close and the song actions on the left; shuffle,
/// repeat, sleep timer and volume on the right. The window buttons, when the
/// app draws them, come after it (see [NowPlayingTitleBar.wrapHeader]).
///
/// [floatingOpen] is set to whether the volume popup or the sleep timer menu
/// is open. Both float outside the header, so whoever hides the header on
/// inactivity listens to it to keep the header shown meanwhile.
class NowPlayingHeader extends StatefulWidget {
  const NowPlayingHeader({
    super.key,
    required this.onClose,
    required this.excludeFromDrag,
    required this.floatingOpen,
    this.hasWindowButtons = false,
    this.modeButton,
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

  @override
  State<NowPlayingHeader> createState() => _NowPlayingHeaderState();
}

class _NowPlayingHeaderState extends State<NowPlayingHeader> {
  bool _volumeOpen = false;
  bool _sleepOpen = false;
  bool _repeatOpen = false;

  void _report() =>
      widget.floatingOpen.value = _volumeOpen || _sleepOpen || _repeatOpen;

  @override
  void dispose() {
    // The popup and the menu leave with the header: give the pin back.
    _volumeOpen = false;
    _sleepOpen = false;
    _repeatOpen = false;
    _report();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exclude = widget.excludeFromDrag;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: nowPlayingHeaderHeight,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _leftInset),
            child: exclude(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NowPlayingCloseButton(onPressed: widget.onClose),
                  ?widget.modeButton,
                  const SizedBox(width: _leftGap),
                  const NowPlayingFavoriteButton(),
                  const NowPlayingPlaylistButton(),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, side) {
                final separator = widget.hasWindowButtons
                    ? _rightSeparatorWidth
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
                            showLabel:
                                side.maxWidth - separator >=
                                _rightButtonsWidth + _sleepLabelWidth,
                            onMenuChanged: (open) {
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
                            width: _rightSeparatorWidth,
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
    );
  }
}

/// Cycles the view mode: its icon shows the mode on screen, its tooltip names
/// the one a press switches to.
class NowPlayingViewModeButton extends StatelessWidget {
  const NowPlayingViewModeButton({
    super.key,
    required this.mode,
    required this.lyricsState,
    required this.onChoose,
  });

  /// The mode on screen (the effective one, see [effectiveViewMode]).
  final NowPlayingViewMode mode;
  final NowPlayingLyricsState lyricsState;
  final ValueChanged<NowPlayingViewMode> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = nextViewMode(mode, lyricsState);
    return IconButton(
      icon: Icon(switch (mode) {
        NowPlayingViewMode.split => AppIcons.viewSplit,
        NowPlayingViewMode.lyricsOnly => AppIcons.lyrics,
        NowPlayingViewMode.coverOnly => AppIcons.viewCover,
      }),
      iconSize: playerIconSize,
      tooltip: switch (next) {
        NowPlayingViewMode.split => l10n.nowPlayingViewSplit,
        NowPlayingViewMode.lyricsOnly => l10n.nowPlayingLyricsOnly,
        NowPlayingViewMode.coverOnly => l10n.nowPlayingViewCoverOnly,
      },
      onPressed: () => onChoose(next),
    );
  }
}
