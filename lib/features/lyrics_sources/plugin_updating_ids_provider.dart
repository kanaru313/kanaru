import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';

/// Install ids the core is updating right now, whoever started it (the store
/// page, update all, the update banner). The controller's stream is
/// subscribed before the current set is added, so no change slips in between.
/// Empty when no repository controller exists.
final pluginUpdatingIdsProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) {
  final controller = ref.watch(lyricsPluginReposControllerProvider);
  if (controller == null) return const Stream.empty();
  final out = StreamController<Set<String>>();
  final sub = controller.updatingChanges.listen(out.add, onError: out.addError);
  out.add(controller.updating);
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
});
