import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/empty_state.dart';

/// What the songs page shows when there is nothing to list.
enum SongsEmptyKind {
  /// The library database could not be opened.
  unavailable,

  /// No music folder has been added.
  noRoots,

  /// Folders exist but hold no songs.
  noTracks,
}

class SongsEmptyView extends StatelessWidget {
  const SongsEmptyView({super.key, required this.kind, this.onChooseFolder});

  final SongsEmptyKind kind;

  /// Opens the folder picker; only used for [SongsEmptyKind.noRoots].
  final VoidCallback? onChooseFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return switch (kind) {
      SongsEmptyKind.unavailable => EmptyState(
        icon: Icons.error_outline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      ),
      SongsEmptyKind.noTracks => EmptyState(
        icon: Icons.music_off_outlined,
        title: l10n.libraryNoTracksTitle,
        message: l10n.libraryNoTracksMessage,
      ),
      SongsEmptyKind.noRoots => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.music_note_outlined,
              title: l10n.libraryEmptyTitle,
              message: l10n.libraryEmptyMessage,
            ),
            FilledButton.icon(
              onPressed: onChooseFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.libraryChooseFolder),
            ),
          ],
        ),
      ),
    };
  }
}
