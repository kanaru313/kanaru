import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/excluded_folders_controller.dart';
import '../../core/indexer/root_path.dart';
import '../../l10n/l10n.dart';
import '../../shared/directory_picker_provider.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/root_rejection_message.dart';
import 'excluded_folders_row.dart';
import 'library_folders_provider.dart';
import 'setting_row.dart';
import '../../shared/widgets/app_snack_bar.dart';

final _log = Logger('settings');

/// The excluded folders with add and remove. Disabled without a library
/// database and while one action (a picker, a write) runs.
class ExcludedFoldersList extends ConsumerStatefulWidget {
  const ExcludedFoldersList({super.key});

  @override
  ConsumerState<ExcludedFoldersList> createState() =>
      _ExcludedFoldersListState();
}

class _ExcludedFoldersListState extends ConsumerState<ExcludedFoldersList> {
  bool _busy = false;

  void _showMessage(AppSnackBarKind kind, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(kind: kind, title: text));
  }

  /// Runs [action] unless another one runs; a failure becomes a message.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final unexpected = context.l10n.libraryUnexpectedError;
    try {
      await action();
    } catch (error, stackTrace) {
      _log.severe('Changing an excluded folder failed', error, stackTrace);
      if (mounted) _showMessage(AppSnackBarKind.error, unexpected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() => _guarded(() async {
    final l10n = context.l10n;
    final path = await ref.read(directoryPickerProvider)();
    if (path == null || !mounted) return;
    final result = await ref.read(excludedFoldersControllerProvider).add(path);
    if (!mounted) return;
    final rejection = result.rejection;
    if (rejection != null) {
      _showMessage(
        AppSnackBarKind.warning,
        rootRejectionMessage(l10n, path, rejection),
      );
    } else if (result.conflict != null) {
      _showMessage(AppSnackBarKind.warning, switch (result.conflict!) {
        ExclusionConflict.sameAsRoot => l10n.excludedFoldersSameAsRoot,
        ExclusionConflict.outsideLibrary => l10n.excludedFoldersOutsideLibrary,
        ExclusionConflict.alreadyExcluded =>
          l10n.excludedFoldersAlreadyExcluded,
      });
    }
  });

  Future<void> _remove(int id, String path) => _guarded(() async {
    final l10n = context.l10n;
    final ok = await ref.read(excludedFoldersControllerProvider).remove(id);
    if (!ok && mounted) {
      _showMessage(
        AppSnackBarKind.error,
        l10n.settingsRemoveFolderFailed(path),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final folders = ref.watch(excludedFoldersProvider).value ?? const [];
    final roots = [
      for (final root
          in ref.watch(libraryRootsProvider).value ?? <LibraryRoot>[])
        root.path,
    ];
    final enabled = ref.watch(libraryDatabaseProvider) != null && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.excludedFoldersTitle,
          subtitle: l10n.excludedFoldersHint,
          control: FilledButton.tonalIcon(
            style: settingButtonStyle(),
            onPressed: enabled ? _add : null,
            icon: const Icon(AppIcons.addFolder),
            label: Text(
              l10n.excludedFoldersAdd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        for (final folder in folders)
          ExcludedFolderRow(
            key: ValueKey(folder.id),
            path: folder.path,
            note: _note(l10n, folder.path, roots),
            enabled: enabled,
            onRemove: () => unawaited(_remove(folder.id, folder.path)),
          ),
      ],
    );
  }

  /// Why [path] does not apply, or `null`. Only a folder below a library
  /// folder is applied by the scan; one that is gone is checked again after
  /// every scan (assumed there while the check runs).
  String? _note(AppLocalizations l10n, String path, List<String> roots) {
    if (!roots.any((root) => root != path && isSameOrInside(root, path))) {
      return l10n.excludedFoldersNotInLibrary;
    }
    return ref.watch(rootFolderPresentProvider(path)).value == false
        ? l10n.excludedFoldersMissing
        : null;
  }
}
