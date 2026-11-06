import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
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
