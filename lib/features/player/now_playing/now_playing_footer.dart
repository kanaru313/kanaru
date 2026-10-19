import 'package:material_ui/material_ui.dart';

import '../playback_controls.dart';
import '../queue/queue_button.dart';
import '../seek_bar.dart';
import '../volume_button.dart';
import 'now_playing_actions.dart';

const nowPlayingFooterHeight = 80.0;

/// Height of the header strip across the top of Now Playing.
const nowPlayingHeaderHeight = 64.0;

/// Widest the controls and seek bar column gets.
const _centerMaxWidth = 480.0;

/// Room each side group keeps at the least.
const _sideMinWidth = 160.0;

/// Bottom strip of the wide Now Playing: close, favorite and playlist on the
/// left; the playback buttons over the seek bar in the middle; volume and
/// the queue on the right.
class NowPlayingFooter extends StatelessWidget {
  const NowPlayingFooter({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: nowPlayingFooterHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
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
                    children: [PlaybackControls(), SeekBar()],
                  ),
                ),
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [VolumeButton(), QueueButton()],
                    ),
                  ),
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
