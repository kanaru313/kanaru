import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/playlist_writes.dart';
import '../../../l10n/app_localizations.dart';
import 'playlist_name_dialog.dart';

final _log = Logger('playlists');

/// Asks for a name and creates the playlist (with [paths], if any) in one
/// transaction. Returns its id and name, or null when cancelled or when
/// saving failed (reported in a snackbar on [messenger]).
///
/// Callers capture [db], [messenger] and [l10n] before their first `await`;
/// nothing here reads the widget tree after the dialog closes.
Future<({int id, String name})?> promptAndCreatePlaylist(
  BuildContext dialogContext,
  LibraryDatabase db,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n, {
  List<String> paths = const [],
}) async {
  final name = await showPlaylistNameDialog(
    dialogContext,
    title: l10n.playlistCreateTitle,
    confirmLabel: l10n.playlistCreateConfirm,
    initialName: l10n.playlistDefaultName,
  );
  if (name == null) return null;
  try {
    final id = await db.createPlaylist(
      name,
      now: DateTime.now().millisecondsSinceEpoch,
      paths: paths,
    );
    return (id: id, name: name);
  } catch (error, stack) {
    _log.severe('Creating a playlist failed', error, stack);
    messenger.showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));
    return null;
  }
}
