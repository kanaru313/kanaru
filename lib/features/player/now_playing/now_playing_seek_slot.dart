import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../waveform/waveform_bar_layout.dart';
import '../waveform/waveform_seek_track.dart';

/// Height of [NowPlayingSeekSlot]. Every layout that reserves room for the
/// slot reads it from here, so the reserve and the slot always agree.
final nowPlayingSeekSlotHeightProvider = Provider<double>(
  (ref) => waveformTrackHeight,
);

/// The seek visual of every wide Now Playing mode, meant to sit in
/// `SeekBar(track: NowPlayingSeekSlot(), trackHeight: ...)`: the waveform of
/// the playing track, or the straight track while there is none. It is the
/// one place to swap when another visual takes over.
class NowPlayingSeekSlot extends StatelessWidget {
  const NowPlayingSeekSlot({super.key});

  @override
  Widget build(BuildContext context) => const WaveformSeekTrack();
}
