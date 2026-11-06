import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/lyrics_target.dart';
import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/player/local_path_of.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_stack.dart';
import '../../lyrics_action_runner.dart';

/// Builds the runner for the song the modal shows, closes the modal stack
/// that contains [context], then runs [action] on the runner. The runner is
/// built first so it holds the container, navigator and [messenger] after the
/// modal leaves the tree, and acts on the song and lyrics the user saw.
void closeStackThenRun(
  BuildContext context, {
  required LyricsSourceResolution source,
  required ScaffoldMessengerState? messenger,
  required Future<void> Function(LyricsActionRunner runner) action,
}) {
  final runner = LyricsActionRunner.snapshot(
    context,
    source: source,
    messenger: messenger,
  );
  closeLayeredModalStack(context);
  unawaited(action(runner));
}

/// The lookup fields of the song the modal shows, or `null` while the
/// library's target is still another song's (it reloads after a track change).
LyricsTarget? lyricsTargetOfSong(WidgetRef ref, String uri) {
  final target = ref.watch(lyricsTargetProvider).value;
  return target != null && target.trackKey == (localPathOf(uri) ?? uri)
      ? target
      : null;
}
