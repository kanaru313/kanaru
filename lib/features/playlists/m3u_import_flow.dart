import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_library_paths.dart';
import '../../core/database/playlist_writes.dart';
import '../../core/m3u/m3u_import.dart';
import '../../core/m3u/m3u_read.dart';
import '../../l10n/l10n.dart';
import 'm3u_file_pickers.dart';
import 'm3u_import_report_dialog.dart';
import 'playlist_routes.dart';

final _log = Logger('playlists');

/// Longest playlist name made from a file name.
const _maxImportedNameLength = 100;

/// Asks for an M3U file, imports it as a new playlist named after the file
/// and opens that playlist. Lines that could not be used are reported in a
/// dialog; a clean import only shows a snackbar. A file with no usable line
/// creates no playlist.
///
/// Everything from the widget tree is captured before the first `await`.
/// Failures are logged and reported, never thrown.
Future<void> importM3uInteractively(WidgetRef ref, BuildContext context) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final pick = ref.read(m3uOpenPickerProvider);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final l10n = context.l10n;
  final navigator = Navigator.of(context, rootNavigator: true);
  void say(String text) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  final String? path;
  try {
    path = await pick(l10n.playlistM3uAllFiles);
  } catch (error, stack) {
    _log.severe('Opening the M3U file picker failed', error, stack);
    say(l10n.playlistM3uImportFailed);
    return;
  }
  if (path == null || !navigator.mounted) return;

  var cancelled = false;
  unawaited(
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => _ImportProgressDialog(
        onCancel: () {
          cancelled = true;
          Navigator.of(dialogContext).pop();
        },
      ),
    ),
  );
  void closeProgress() {
    if (!cancelled && navigator.mounted) navigator.pop();
  }

  final M3uImportResult result;
  try {
    result = await importM3uFile(path, cancelled: () => cancelled);
  } on M3uImportCancelled {
    return;
  } on M3uReadException catch (error) {
    closeProgress();
    if (cancelled) return;
    _log.warning('Reading the M3U file failed: ${error.error.name}');
    say(
      error.error == M3uReadError.tooLarge
          ? l10n.playlistM3uImportTooLarge
          : l10n.playlistM3uImportFailed,
    );
    return;
  } catch (error, stack) {
    closeProgress();
    if (cancelled) return;
    _log.severe('Importing an M3U file failed', error, stack);
    say(l10n.playlistM3uImportFailed);
    return;
  }
  if (cancelled) return;
  closeProgress();

  Future<void> report({required int added, required int notInLibrary}) async {
    if (!navigator.mounted) return;
    await showM3uImportReport(
      navigator.context,
      result: result,
      added: added,
      notInLibrary: notInLibrary,
    );
  }

  if (result.paths.isEmpty) {
    await report(added: 0, notInLibrary: 0);
    return;
  }
  final name = playlistNameFromM3uFile(path, l10n.playlistDefaultName);
  final int id;
  final int notInLibrary;
  try {
    notInLibrary =
        result.paths.length - (await db.libraryPathsAmong(result.paths)).length;
    id = await db.createPlaylist(
      name,
      now: DateTime.now().millisecondsSinceEpoch,
      paths: result.paths,
    );
  } catch (error, stack) {
    _log.severe('Saving an imported playlist failed', error, stack);
    // No report: its counts would describe a playlist that was not saved.
    say(l10n.playlistSaveFailed);
    return;
  }
  router.go(playlistLocation(id));
  if (result.unresolved.isNotEmpty ||
      result.duplicates > 0 ||
      result.truncated) {
    await report(added: result.paths.length, notInLibrary: notInLibrary);
    return;
  }
  final imported = l10n.playlistM3uImported(result.paths.length, name);
  say(
    notInLibrary == 0
        ? imported
        : '$imported · ${l10n.playlistM3uImportedNotInLibrary(notInLibrary)}',
  );
}

/// A playlist name from the M3U file at [path]: the file name without its
/// `.m3u`/`.m3u8` extension (any case), control and bidi override characters
/// as spaces, trimmed, at most 100 characters; [fallback] when nothing is
/// left (a file named `.m3u8`).
String playlistNameFromM3uFile(String path, String fallback) {
  var name = path.substring(path.lastIndexOf('/') + 1);
  final extension = RegExp(r'\.m3u8?$', caseSensitive: false);
  name = name.replaceFirst(extension, '');
  name = name
      .replaceAll(
        RegExp(r'[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]'),
        ' ',
      )
      .trim();
  if (name.length > _maxImportedNameLength) {
    name = name.substring(0, _maxImportedNameLength).trim();
  }
  return name.isEmpty ? fallback : name;
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Row(
      children: [
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(context.l10n.playlistM3uImporting)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: onCancel,
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
  );
}
