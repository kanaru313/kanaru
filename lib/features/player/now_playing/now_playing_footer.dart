import 'package:material_ui/material_ui.dart';

import '../playback_controls.dart';
import '../queue/queue_button.dart';
import '../seek_bar.dart';
import '../sleep_timer/sleep_timer_button.dart';
import '../volume_button.dart';
import 'now_playing_actions.dart';

const nowPlayingFooterHeight = 80.0;

/// Height of the header strip across the top of Now Playing.
const nowPlayingHeaderHeight = 64.0;

/// Widest the controls and seek bar column gets.
const _centerMaxWidth = 480.0;

/// Air between the controls and the window's bottom edge.
const _bottomGap = 16.0;

/// Width of the right group at which the sleep timer label fits beside its
/// three buttons.
const _sleepLabelMinSide = 200.0;

/// Room each side group keeps at the least.
const _sideMinWidth = 160.0;

/// Bottom strip of the wide Now Playing: close, favorite and playlist on the
/// left; the playback buttons over the seek bar in the middle; the sleep timer,
/// volume and the queue on the right.
class NowPlayingFooter extends StatelessWidget {
  const NowPlayingFooter({
    super.key,
    required this.onClose,
    this.onVolumePopupChanged,
  });

  final VoidCallback onClose;

  /// The volume popup or the sleep timer menu opened (`true`) or both closed;
  /// they float outside the footer, so the screen uses this to keep the
  /// footer shown meanwhile.
  final ValueChanged<bool>? onVolumePopupChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: nowPlayingFooterHeight + _bottomGap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, _bottomGap),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final center = (constraints.maxWidth - 2 * _sideMinWidth).clamp(
              0.0,
              _centerMaxWidth,
            );
            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Left(onClose: onClose),
                  ),
                ),
                SizedBox(
                  width: center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [PlaybackControls(spacing: 20), SeekBar()],
                  ),
                ),
                Expanded(
                  child: _Right(onFloatingChanged: onVolumePopupChanged),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Left extends StatelessWidget {
  const _Left({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NowPlayingCloseButton(onPressed: onClose),
        const NowPlayingFavoriteButton(),
        const NowPlayingPlaylistButton(),
      ],
    );
  }
}

/// Right group: sleep timer, volume and queue. Reports to
/// [onFloatingChanged] whether the volume popup or the sleep timer menu is
/// open (each floats outside the footer), only when that changes.
class _Right extends StatefulWidget {
  const _Right({this.onFloatingChanged});

  final ValueChanged<bool>? onFloatingChanged;

  @override
  State<_Right> createState() => _RightState();
}

class _RightState extends State<_Right> {
  bool _volumeOpen = false;
  bool _sleepOpen = false;
  bool _reported = false;

  void _report() {
    final open = _volumeOpen || _sleepOpen;
    if (open == _reported) return;
    _reported = open;
    widget.onFloatingChanged?.call(open);
  }

  @override
  void dispose() {
    _volumeOpen = false;
    _sleepOpen = false;
    _report();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, side) => Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SleepTimerButton(
                showLabel: side.maxWidth >= _sleepLabelMinSide,
                onMenuChanged: (open) {
                  _sleepOpen = open;
                  _report();
                },
              ),
            ),
            VolumeButton(
              onPopupChanged: (open) {
                _volumeOpen = open;
                _report();
              },
            ),
            const QueueButton(),
          ],
        ),
      ),
    );
  }
}
