import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/online_lyrics_queries.dart';
import '../../core/lyrics/online/lyrics_provider.dart';
import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/lyrics/online/lyrics_target.dart';
import '../../core/lyrics/online/online_lyrics_actions.dart';
import '../../l10n/l10n.dart';
import '../online_lyrics_notice_dialog.dart';
import '../widgets/app_snack_bar.dart';
import 'lyrics_picker_dialog.dart';

final _log = Logger('lyrics_picker');

/// Opens the Choose lyrics dialog for [target] and pins what the user picks.
///
/// Works from a menu that has left the tree: it needs only the root
/// [navigator] and the [container], never a `WidgetRef`. The consent notice
/// comes first; on Cancel nothing opens and nothing is sent. The dialog is
/// built on the navigator's context under [container]. After a pick the
/// lyrics are pinned (no file is written) and
/// [messenger] (else the navigator's) tells the result.
Future<void> showLyricsPicker({
  required NavigatorState navigator,
  required ProviderContainer container,
  required LyricsTarget target,
  ScaffoldMessengerState? messenger,
}) async {
  for (final registration in container.read(lyricsProvidersProvider)) {
    final accepted = await confirmOnlineLyricsNotice(
      navigator,
      container,
      registration,
      auto: false,
    );
    if (!accepted) return;
  }
  // The library's row is the one both entry points agree on, so a song has
  // one cache key whichever menu opened the dialog.
  final song = await _libraryTarget(container, target);
  if (!navigator.mounted) return;
  final picked = await showDialog<LyricsCandidate>(
    context: navigator.context,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: LyricsPickerDialog(target: song),
    ),
  );
  if (picked == null || !navigator.mounted) return;
  await _pin(navigator, container, song, picked, messenger);
}

/// [target] re-read from the library by path; [target] itself for a song
/// outside the library or without one.
Future<LyricsTarget> _libraryTarget(
  ProviderContainer container,
  LyricsTarget target,
) async {
  final path = target.path;
  final db = container.read(libraryDatabaseProvider);
  if (path == null || db == null) return target;
  try {
    final fields = await db.watchTrackLyricsFields(path).first;
    return fields == null
        ? target
        : LyricsTarget.fromLibraryFields(path, fields);
  } on Object catch (e) {
    _log.warning('could not read the song from the library: ${e.runtimeType}');
    return target;
  }
}

Future<void> _pin(
  NavigatorState navigator,
  ProviderContainer container,
  LyricsTarget target,
  LyricsCandidate picked,
  ScaffoldMessengerState? messenger,
) async {
  Object? failure;
  try {
    await container.read(onlineLyricsActionsProvider).pick(target, picked);
  } on Object catch (e) {
    _log.warning('could not pin lyrics: ${e.runtimeType}');
    failure = e;
  }
  if (!navigator.mounted) return;
  final l10n = navigator.context.l10n;
  final bar = messenger ?? ScaffoldMessenger.maybeOf(navigator.context);
  if (failure != null) {
    bar?.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: l10n.lyricsPickFailed),
    );
    return;
  }
  bar?.showSnackBar(
    appSnackBar(kind: AppSnackBarKind.success, title: l10n.lyricsPinned),
  );
}
