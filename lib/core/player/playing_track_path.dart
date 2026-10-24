import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_path_of.dart';
import 'player_service.dart';

/// Local path of the playing track, or null: nothing playing, or a track
/// that is not a local file. Same while paused. Song rows compare it with
/// their library path.
///
/// Selects only the current uri.
final playingTrackPathProvider = Provider<String?>((ref) {
  final uri = ref.watch(
    playerServiceProvider.select((s) => s.queue.current?.uri),
  );
  return uri == null ? null : localPathOf(uri);
});
