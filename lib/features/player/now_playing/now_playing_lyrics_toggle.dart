import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/lyrics/online/lyrics_choice.dart';
import '../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../core/player/local_path_of.dart';
import '../lyrics/lyrics_action_runner.dart';

/// Whether the lyrics of the song of [source] can be changed: the library is
/// open and the song is a local file (choices are stored per local song).
///
/// Watches the library, so a widget that calls it in `build` rebuilds when the
/// library opens or closes; [quickToggleLyrics] calls it from an event, where
/// watching the same provider is harmless (it only reads the current value).
bool lyricsCanChoose(WidgetRef ref, LyricsSourceResolution source) =>
    ref.watch(libraryDatabaseProvider) != null &&
    localPathOf(source.status.uri) != null;

/// Turns the playing song's lyrics off, or back on to what they were, from a
/// secondary tap on the lyrics button. With the choice `off` it turns lyrics
/// on (the file's own lyrics come back as local, else the stored pick, else
/// the fixed order); otherwise it chooses `off`. Returns `false` when there is
/// nothing to change (no song, or [lyricsCanChoose] is false).
///
/// [messenger] shows the snackbar of a failed action; the runner takes the
/// one above [context] when it is `null`.
bool quickToggleLyrics(
  BuildContext context,
  WidgetRef ref, {
  ScaffoldMessengerState? messenger,
}) {
  final source = ref.read(playingLyricsSourceProvider);
  if (source == null || !lyricsCanChoose(ref, source)) return false;
  final runner = LyricsActionRunner.snapshot(
    context,
    source: source,
    messenger: messenger,
  );
  unawaited(
    source.chosen == LyricsChoice.off
        ? runner.turnOn()
        : runner.choose(LyricsChoice.off),
  );
  return true;
}
