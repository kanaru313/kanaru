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
import 'settings_busy_tasks.dart';
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
  /// Runs [action] unless another one runs; a failure becomes a message.
  /// The busy flag and the messenger outlive this row, so leaving the page
  /// mid-action neither re-enables the buttons nor drops the message.
  Future<void> _guarded(
    Future<void> Function(ScaffoldMessengerState messenger) action,
  ) async {
    final busy = ref.read(settingsBusyTasksProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final unexpected = context.l10n.libraryUnexpectedError;
    if (!busy.start(SettingsTask.excludedFolders)) return;
    try {
      await action(messenger);
    } catch (error, stackTrace) {
      _log.severe('Changing an excluded folder failed', error, stackTrace);
      messenger.showAppSnackBar(AppSnackBarKind.error, unexpected);
    } finally {
      busy.finish(SettingsTask.excludedFolders);
    }
  }

  Future<void> _add() => _guarded((messenger) async {
    final l10n = context.l10n;
    final controller = ref.read(excludedFoldersControllerProvider);
    final path = await ref.read(directoryPickerProvider)();
    if (path == null || !mounted) return;
    final result = await controller.add(path);
    final rejection = result.rejection;
    final conflict = result.conflict;
    if (rejection != null) {
      messenger.showAppSnackBar(
        AppSnackBarKind.warning,
        rootRejectionMessage(l10n, path, rejection),
      );
    } else if (conflict != null) {
      messenger.showAppSnackBar(AppSnackBarKind.warning, switch (conflict) {
        ExclusionConflict.sameAsRoot => l10n.excludedFoldersSameAsRoot,
        ExclusionConflict.outsideLibrary => l10n.excludedFoldersOutsideLibrary,
        ExclusionConflict.alreadyExcluded =>
          l10n.excludedFoldersAlreadyExcluded,
      });
    }
  });

  Future<void> _remove(int id, String path) => _guarded((messenger) async {
    final l10n = context.l10n;
    final ok = await ref.read(excludedFoldersControllerProvider).remove(id);
    if (!ok) {
      messenger.showAppSnackBar(
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
    final busy = ref.watch(
      settingsBusyTasksProvider.select(
        (s) => s.contains(SettingsTask.excludedFolders),
      ),
    );
    final enabled = ref.watch(libraryDatabaseProvider) != null && !busy;

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
