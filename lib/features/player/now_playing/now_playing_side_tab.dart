import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs of the Split side pane.
enum NowPlayingSideTab { lyrics, queue }

/// The side tab the user chose. Kept for the running app only, like the view
/// mode: it survives track changes, closing and reopening Now Playing, mode
/// switches and resizes, and is never saved. The first opening shows Lyrics.
class NowPlayingSideTabNotifier extends Notifier<NowPlayingSideTab> {
  @override
  NowPlayingSideTab build() => NowPlayingSideTab.lyrics;

  void choose(NowPlayingSideTab tab) => state = tab;
}

final nowPlayingSideTabProvider =
    NotifierProvider<NowPlayingSideTabNotifier, NowPlayingSideTab>(
      NowPlayingSideTabNotifier.new,
    );
