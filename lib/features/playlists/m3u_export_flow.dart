import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show LibraryDatabase;
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_write.dart';
import '../../l10n/l10n.dart';
import '../../shared/m3u/m3u_export_flow.dart';
import '../../shared/m3u/m3u_save_picker.dart';
import 'm3u_import_flow.dart' show playlistNameFromM3uFile;
import 'playlist_display_name.dart';

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
) => exportPlaylistWith(
  save: ref.read(m3uSavePickerProvider),
  db: ref.read(libraryDatabaseProvider),
  messenger: ScaffoldMessenger.of(context),
  l10n: context.l10n,
  navigator: Navigator.of(context, rootNavigator: true),
  playlist: playlist,
  style: style,
);

/// [exportPlaylistInteractively] with everything it needs from the widget
/// tree already captured, for a caller whose widget may be gone by the time
/// the file is chosen (the playlist modal). [navigator] is the root
/// navigator, which hosts the overwrite question.
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
