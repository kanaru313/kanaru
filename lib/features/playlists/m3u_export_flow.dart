import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show LibraryDatabase;
import '../../core/database/playlist_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_write.dart';
import '../../l10n/l10n.dart';
import '../../shared/m3u/m3u_export_flow.dart';
import '../../shared/m3u/m3u_save_picker.dart';
import 'm3u_import_flow.dart' show playlistNameFromM3uFile;
import 'playlist_display_name.dart';

/// Asks where to save [playlist] as an M3U file with [style] paths and writes
/// it, with everything it needs from the widget tree already captured (the
/// caller's widget may be gone by the time the file is chosen). [navigator]
/// is the root navigator, which hosts the overwrite question.
Future<void> exportPlaylistWith({
  required M3uSavePicker save,
  required LibraryDatabase? db,
  required ScaffoldMessengerState? messenger,
  required AppLocalizations l10n,
  required NavigatorState? navigator,
  required PlaylistSummary playlist,
  required M3uPathStyle style,
}) => exportM3uWith(
  save: save,
  messenger: messenger,
  l10n: l10n,
  navigator: navigator,
  name: playlistNameFromM3uFile(
    playlistDisplayName(playlist, l10n),
    l10n.playlistDefaultName,
  ),
  style: style,
  readEntries: () async {
    final page = db == null ? null : await db.playlistPage(playlist.id);
    if (page == null) return null;
    return [
      for (final entry in page.entries)
        M3uExportEntry(
          path: entry.path,
          title: entry.track?.title,
          artist: entry.track?.artist,
          durationMs: entry.track?.durationMs,
        ),
    ];
  },
);
