import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_root_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/root_path.dart';
import '../../l10n/l10n.dart';
import '../../shared/directory_picker_provider.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/root_rejection_message.dart';
import 'library_folder_dialogs.dart';
import 'library_folder_row.dart';
import 'library_folders_provider.dart';
import 'setting_row.dart';

final _log = Logger('settings');

/// The library folders with add, change and remove. Everything is disabled
/// without a library database, and while one action (a picker, a dialog, a
/// write) is running.
class LibraryFoldersList extends ConsumerStatefulWidget {
  const LibraryFoldersList({super.key});

  @override
  ConsumerState<LibraryFoldersList> createState() => _LibraryFoldersListState();
}

class _LibraryFoldersListState extends ConsumerState<LibraryFoldersList> {
  bool _busy = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs [action] unless another one runs; a failure becomes a message.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final unexpected = context.l10n.libraryUnexpectedError;
    try {
      await action();
    } catch (error, stackTrace) {
      _log.severe('Changing a library folder failed', error, stackTrace);
      if (mounted) _showMessage(unexpected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Failures of the scan land in the indexer state, never in the zone.
  void _scan() => unawaited(ref.read(libraryIndexerProvider.notifier).scan());

  Future<void> _add() => _guarded(() async {
    final l10n = context.l10n;
    final path = await ref.read(directoryPickerProvider)();
    if (path == null || !mounted) return;
    final result = await ref.read(libraryRootsControllerProvider).addRoots([
      path,
    ]);
    if (!mounted) return;
    if (result.added.isEmpty) {
      _showMessage(rootRejectionsMessage(l10n, result.rejected));
      return;
    }
    _scan();
  });

  Future<void> _remove(LibraryRoot root) => _guarded(() async {
    final l10n = context.l10n;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final songs = await db.trackCountOfRoot(root.id);
    if (!mounted) return;
    final confirmed = await confirmRemoveFolder(
      context,
      path: root.path,
      songCount: songs,
    );
    if (!confirmed || !mounted) return;
    final result = await ref
        .read(libraryRootsControllerProvider)
        .removeRoot(root.id);
    if (!result.ok && mounted) {
      _showMessage(l10n.settingsRemoveFolderFailed(root.path));
    }
  });

  Future<void> _change(LibraryRoot root) => _guarded(() async {
    final l10n = context.l10n;
    final picked = await ref.read(directoryPickerProvider)();
    if (picked == null || !mounted) return;
    // Compare and confirm with the path that would be stored.
    final checked = await canonicalizeRoot(picked);
    if (!mounted) return;
    final canonical = checked.path;
    if (canonical == null) {
      _showMessage(rootRejectionMessage(l10n, picked, checked.rejection!));
      return;
    }
    if (canonical == root.path) return;
    final confirmed = await confirmReplaceFolder(
      context,
      oldPath: root.path,
      newPath: canonical,
    );
    if (!confirmed || !mounted) return;
    final result = await ref
        .read(libraryRootsControllerProvider)
        .replaceRoot(root.id, canonical);
    if (!mounted) return;
    if (result.rejection == RootRejection.notFound) {
      // The folder being replaced left the library meanwhile: the list has
      // already dropped its row, so there is nothing to report.
    } else if (!result.ok) {
      _showMessage(rootRejectionMessage(l10n, canonical, result.rejection!));
    } else if (!result.unchanged) {
      _scan();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roots = ref.watch(libraryRootsProvider).value ?? const [];
    final enabled = ref.watch(libraryDatabaseProvider) != null && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsFolders,
          subtitle: l10n.settingsFoldersHint,
          control: FilledButton.tonalIcon(
            style: settingButtonStyle(),
            onPressed: enabled ? _add : null,
            icon: const Icon(AppIcons.addFolder),
            label: Text(
              l10n.settingsAddFolder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (roots.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.libraryEmptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final root in roots)
          LibraryFolderRow(
            key: ValueKey(root.id),
            path: root.path,
            // Assumed there while the check runs.
            missing:
                ref.watch(rootFolderPresentProvider(root.path)).value == false,
            enabled: enabled,
            onChange: () => unawaited(_change(root)),
            onRemove: () => unawaited(_remove(root)),
          ),
      ],
    );
  }
}
