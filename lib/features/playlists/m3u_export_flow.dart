import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_export.dart';
import '../../core/m3u/m3u_write.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'm3u_file_pickers.dart';
import 'm3u_import_flow.dart' show playlistNameFromM3uFile;
import 'playlist_display_name.dart';

final _log = Logger('playlists');

/// Set while an export runs: a second one waits for no dialog of its own.
bool _exporting = false;

/// Asks where to save [playlist] as an M3U file with [style] paths and writes
/// it. Adds `.m3u8` to a name without an M3U extension, and asks before
/// overwriting a file (the system save dialog does not). The entries are read
/// once the file is chosen, the one place that needs the whole playlist at
/// hand; they are written in their saved order, and entries not in the
/// library keep their path.
///
/// Everything from the widget tree is captured before the first `await`.
/// Failures are logged and reported, never thrown.
Future<void> exportPlaylistInteractively(
  WidgetRef ref,
  BuildContext context,
  PlaylistSummary playlist,
  M3uPathStyle style,
) async {
  if (_exporting) return;
  _exporting = true;
  try {
    final save = ref.read(m3uSavePickerProvider);
    final db = ref.read(libraryDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final navigator = Navigator.of(context, rootNavigator: true);
    void say(AppSnackBarKind kind, String text, {String? details}) => messenger
      ..clearSnackBars()
      ..showSnackBar(appSnackBar(kind: kind, title: text, details: details));

    final name = playlistNameFromM3uFile(
      playlistDisplayName(playlist, l10n),
      l10n.playlistDefaultName,
    );
    try {
      final picked = await save('$name.m3u8');
      if (picked == null) return;
      final target = m3uExportTarget(picked);
      final exists =
          await FileSystemEntity.type(target, followLinks: false) !=
          FileSystemEntityType.notFound;
      if (exists) {
        if (!navigator.mounted) return;
        final file = target.substring(target.lastIndexOf('/') + 1);
        if (!await _confirmOverwrite(navigator.context, file)) return;
      }
      final page = db == null ? null : await db.playlistPage(playlist.id);
      if (page == null) {
        // Deleted since the page opened, or no library: nothing to write.
        _log.warning('Exporting playlist ${playlist.id}: it is not readable');
        say(AppSnackBarKind.error, l10n.playlistM3uExportFailed);
        return;
      }
      final result = await exportM3uFile(target, [
        for (final entry in page.entries)
          M3uExportEntry(
            path: entry.path,
            title: entry.track?.title,
            artist: entry.track?.artist,
            durationMs: entry.track?.durationMs,
          ),
      ], style);
      final file = target.substring(target.lastIndexOf('/') + 1);
      final exported = l10n.playlistM3uExported(result.written, file);
      say(
        result.skipped == 0 ? AppSnackBarKind.success : AppSnackBarKind.warning,
        exported,
        details: result.skipped == 0
            ? null
            : l10n.playlistM3uExportSkipped(result.skipped),
      );
    } catch (error, stack) {
      _log.severe('Exporting a playlist failed', error, stack);
      say(AppSnackBarKind.error, l10n.playlistM3uExportFailed);
    }
  } finally {
    _exporting = false;
  }
}

/// [picked] with `.m3u8` added unless it already ends in `.m3u` or `.m3u8`
/// (any case).
String m3uExportTarget(String picked) =>
    RegExp(r'\.m3u8?$', caseSensitive: false).hasMatch(picked)
    ? picked
    : '$picked.m3u8';

Future<bool> _confirmOverwrite(BuildContext context, String file) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistM3uOverwriteTitle(file)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.playlistM3uOverwriteConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
