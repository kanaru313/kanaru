import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/database/playlist_edit_writes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'playlist_edit_dialog.dart';

final _log = Logger('playlists');

/// Shows the edit dialog for [playlist] (the latest summary the caller has)
/// above [dialogContext], a root-navigator context, and writes the result.
/// The write always runs on Save; the database skips a no-op. A failure is
/// logged and reported in [modalMessenger] while it is still mounted, else in
/// [openerMessenger]; it never throws to the caller.
///
/// Everything from the widget tree is captured by the caller before the
/// first `await`, so the opener may be rebuilt away while the dialog is open.
Future<void> editPlaylistWith({
  required LibraryDatabase db,
  required ScaffoldMessengerState? modalMessenger,
  required ScaffoldMessengerState? openerMessenger,
  required AppLocalizations l10n,
  required BuildContext dialogContext,
  required PlaylistSummary playlist,
  required List<String> coverKeys,
}) async {
  final edit = await showPlaylistEditDialog(
    dialogContext,
    playlist: playlist,
    coverKeys: coverKeys,
  );
  if (edit == null) return;
  try {
    await db.updatePlaylistDetails(
      playlist.id,
      name: edit.name,
      description: edit.description,
    );
  } catch (error, stack) {
    _log.warning('Saving playlist ${playlist.id} failed', error, stack);
    _report(
      modalMessenger?.mounted == true ? modalMessenger : openerMessenger,
      l10n.playlistSaveFailed,
    );
  }
}

void _report(ScaffoldMessengerState? messenger, String text) {
  try {
    messenger?.showAppSnackBar(AppSnackBarKind.error, text);
  } catch (error, stack) {
    _log.warning('Showing the playlist message failed', error, stack);
  }
}
