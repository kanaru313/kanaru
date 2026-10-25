import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../seek_bar.dart';
import '../waveform/waveform_bar_layout.dart';
import '../waveform/waveform_seek_track.dart';

/// Whether Settings -> Appearance asks for the waveform seek bar.
final _waveformSeekBarProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.display.waveformSeekBar)),
);

/// Height of [NowPlayingSeekSlot]: the tall waveform track, or the flat
/// track's own hit height when the waveform is turned off. Every layout that
/// reserves room for the slot reads it from here, so the reserve and the
/// slot always agree.
final nowPlayingSeekSlotHeightProvider = Provider<double>(
  (ref) =>
      ref.watch(_waveformSeekBarProvider) ? waveformTrackHeight : seekHitHeight,
);

/// The seek visual of every wide Now Playing mode, meant to sit in
/// `SeekBar(track: NowPlayingSeekSlot(), trackHeight: ...)`: the waveform of
/// the playing track (the straight track while there is none), or the plain
/// straight track when the waveform seek bar is turned off. With it off no
/// waveform widget is mounted, so nothing is decoded or prefetched.
class NowPlayingSeekSlot extends ConsumerWidget {
  const NowPlayingSeekSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_waveformSeekBarProvider)
      ? const WaveformSeekTrack()
      : const SeekTrack();
}
