import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/waveform/waveform_controller.dart';
import '../seek_gesture_area.dart';
import '../seek_track_painter.dart';
import 'waveform_bar_layout.dart';
import 'waveform_pictures.dart';
import 'waveform_track_painter.dart';

/// How long the bars take to fade in over the straight track.
const waveformFadeDuration = Duration(milliseconds: 200);

/// Seek track that draws the waveform of the playing track as mirrored bars,
/// or the straight track while there is none (loading, unsupported file,
/// unknown duration). Seeking is [SeekGestureArea]'s, unchanged.
///
/// While mounted it keeps the [WaveformController] loading. The bars fade in
/// when the data arrives after the first build, and show at once when it is
/// there already or when animations are off.
class WaveformSeekTrack extends ConsumerStatefulWidget {
  const WaveformSeekTrack({super.key});

  @override
  ConsumerState<WaveformSeekTrack> createState() => _WaveformSeekTrackState();
}

class _WaveformSeekTrackState extends ConsumerState<WaveformSeekTrack>
    with SingleTickerProviderStateMixin {
  // Read once: `ref` cannot be used while the element unmounts.
  late final WaveformController _controller;
  final _pictures = WaveformPictures();
  late final AnimationController _fade;

  /// Whether the last build had bars to show; `null` before the first build.
  bool? _wasReady;

  /// The playing uri the last build saw, and whether the controller already
  /// held its waveform then. The player resets the duration to zero on a
  /// track change until the engine reports it, so "data came with the track"
  /// is decided here, not when the bars become ready: such bars show at once.
  String? _uriSeen;
  bool _hadDataAtUri = false;

  /// The bars are fully shown, so the straight track below is not drawn.
  bool _fadeDone = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(waveformControllerProvider.notifier);
    _controller.attach();
    _fade = AnimationController(vsync: this, duration: waveformFadeDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fadeDone && mounted) {
          setState(() => _fadeDone = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.detach();
    _fade.dispose();
    _pictures.dispose();
    super.dispose();
  }

  /// Starts, finishes or resets the fade for a change of [ready].
  void _syncFade(bool ready, {required bool instant}) {
    final before = _wasReady;
    _wasReady = ready;
    if (ready == before) return;
    if (!ready) {
      _fadeDone = false;
      _fade.value = 0;
    } else if (before == null || instant) {
      // Marked first: setting the value reports completion mid-build.
      _fadeDone = true;
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final (playingUri, duration) = ref.watch(
      playerServiceProvider.select((s) => (s.queue.current?.uri, s.duration)),
    );
    final shown = ref.watch(waveformControllerProvider);
    // Never the previous track's bars: they must belong to the playing uri.
    final waveform = shown != null && shown.uri == playingUri
        ? shown.waveform
        : null;
    final ready = waveform != null && duration > Duration.zero;
    if (playingUri != _uriSeen) {
      _uriSeen = playingUri;
      _hadDataAtUri = shown != null && shown.uri == playingUri;
    }
    _syncFade(ready, instant: instant || _hadDataAtUri);
    if (!ready) _pictures.dispose();

    return SeekGestureArea(
      height: waveformTrackHeight,
      builder: (context, state) {
        final size = Size(state.width, waveformTrackHeight);
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_fadeDone)
                CustomPaint(
                  painter: SeekTrackPainter(
                    progress: state.progress,
                    playedColor: colors.primary,
                    restColor: colors.secondaryContainer,
                  ),
                ),
              if (ready)
                FadeTransition(
                  opacity: _fade,
                  child: CustomPaint(
                    painter: WaveformTrackPainter(
                      progress: state.progress,
                      thumbColor: colors.primary,
                      pictures: _pictures.pair((
                        waveform: waveform,
                        size: size,
                        devicePixelRatio: dpr,
                        durationMs: duration.inMilliseconds,
                        played: colors.primary,
                        rest: colors.secondaryContainer,
                      )),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
