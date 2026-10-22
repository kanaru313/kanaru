import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
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
        icon: AppIcons.errorOutline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      ),
      SongsEmptyKind.noTracks => EmptyState(
        icon: AppIcons.musicOff,
        title: l10n.libraryNoTracksTitle,
        message: l10n.libraryNoTracksMessage,
      ),
      SongsEmptyKind.noRoots => EmptyState(
        icon: AppIcons.musicNoteOutlined,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
        action: FilledButton.icon(
          onPressed: onChooseFolder,
          icon: const Icon(AppIcons.folderOpen),
          label: Text(l10n.libraryChooseFolder),
        ),
      ),
    };
  }
}
