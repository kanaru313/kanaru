import 'dart:io';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/m3u/m3u_export.dart';
import '../../core/m3u/m3u_text.dart';
import '../../core/m3u/m3u_write.dart';
import '../../l10n/l10n.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/confirm_dialog.dart';
import 'm3u_save_picker.dart';

final _log = Logger('m3u');

/// Longest file base name suggested to the save dialog, in characters.
const _maxFileNameLength = 100;

/// Set while an export runs: a second one waits for no dialog of its own.
bool _exporting = false;

/// Asks where to save an M3U file named after [name] and writes the entries
/// [readEntries] returns, with [style] paths. Adds `.m3u8` to a name without
/// an M3U extension, and asks before overwriting a file (the system save
/// dialog does not). The entries are read once the file is chosen, the one
/// place that needs the whole list at hand; they are written in the order
/// given, and entries not in the library keep their path.
///
/// [name] is a bare title, not a file name: no extension or path is stripped
/// from it (`.m3u8` is added to the suggestion). It is cleaned of control and bidi characters and cut to 100
/// characters; an empty result becomes the default playlist name.
/// [readEntries] returns null when the source can no longer be read (a
/// failure snackbar), and an empty list for an empty source (an empty file).
/// [navigator] is the root navigator, which hosts the overwrite question.
///
/// Everything from the widget tree is captured by the caller before its first
/// `await`. Failures are logged and reported, never thrown.
Future<void> exportM3uWith({
  required M3uSavePicker save,
  required ScaffoldMessengerState? messenger,
  required AppLocalizations l10n,
  required NavigatorState? navigator,
  required String name,
  required M3uPathStyle style,
  required Future<List<M3uExportEntry>?> Function() readEntries,
}) async {
  if (_exporting) return;
  _exporting = true;
  try {
    void say(AppSnackBarKind kind, String text, {String? details}) {
      try {
        messenger?.showAppSnackBar(kind, text, details: details);
      } catch (error, stack) {
        _log.warning('Showing the export message failed', error, stack);
      }
    }

    try {
      final picked = await save('${_fileBaseName(name, l10n)}.m3u8');
      if (picked == null) return;
      final target = m3uExportTarget(picked);
      final exists =
          await FileSystemEntity.type(target, followLinks: false) !=
          FileSystemEntityType.notFound;
      if (exists) {
        if (navigator == null || !navigator.mounted) return;
        final file = target.substring(target.lastIndexOf('/') + 1);
        if (!await _confirmOverwrite(navigator.context, file)) return;
      }
      final entries = await readEntries();
      if (entries == null) {
        // Deleted since the page opened, or no library: nothing to write.
        _log.warning('Exporting "$name": it is not readable');
        say(AppSnackBarKind.error, l10n.playlistM3uExportFailed);
        return;
      }
      final result = await exportM3uFile(target, entries, style);
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
      _log.severe('Exporting an M3U file failed', error, stack);
      say(AppSnackBarKind.error, l10n.playlistM3uExportFailed);
    }
  } finally {
    _exporting = false;
  }
}

/// [name] without control and bidi characters, trimmed, at most 100
/// characters; the default playlist name when nothing is left.
String _fileBaseName(String name, AppLocalizations l10n) {
  var clean = name.replaceAll(m3uUnsafeTextChars, ' ').trim();
  final characters = clean.characters;
  if (characters.length > _maxFileNameLength) {
    clean = characters.take(_maxFileNameLength).string.trim();
  }
  return clean.isEmpty ? l10n.playlistDefaultName : clean;
}

/// [picked] with `.m3u8` added unless it already ends in `.m3u` or `.m3u8`
/// (any case).
String m3uExportTarget(String picked) =>
    RegExp(r'\.m3u8?$', caseSensitive: false).hasMatch(picked)
    ? picked
    : '$picked.m3u8';

Future<bool> _confirmOverwrite(BuildContext context, String file) {
  final l10n = context.l10n;
  return confirmAction(
    context,
    title: l10n.playlistM3uOverwriteTitle(file),
    confirmLabel: l10n.playlistM3uOverwriteConfirm,
    destructive: false,
  );
}
