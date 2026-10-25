import 'package:material_ui/material_ui.dart';

import '../seek_bar.dart';

/// The seek visual of every Now Playing mode, meant to sit in
/// `SeekBar(track: NowPlayingSeekSlot())`. It is the one place to swap when
/// the straight track gives way to another visual.
class NowPlayingSeekSlot extends StatelessWidget {
  const NowPlayingSeekSlot({super.key});

  @override
  Widget build(BuildContext context) => const SeekTrack();
}
