import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/player/player_service.dart';

/// Whether the Now Playing overlay is open. It is a flag, not a route, so the
/// shell (title bar, history, page state) stays untouched underneath.
final nowPlayingOpenProvider = NotifierProvider<NowPlayingOpen, bool>(
  NowPlayingOpen.new,
);

class NowPlayingOpen extends Notifier<bool> {
  @override
  bool build() {
    // Nothing left to show once the queue is emptied.
    ref.listen(playerServiceProvider.select((s) => s.queue.isEmpty), (
      _,
      empty,
    ) {
      if (empty) state = false;
    });
    return false;
  }

  /// Does nothing while the queue is empty, e.g. while a folder is scanned.
  void open() {
    if (ref.read(playerServiceProvider).queue.isEmpty) return;
    state = true;
  }

  void close() => state = false;
}
