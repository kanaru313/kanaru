import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/indexer_providers.dart';
import '../../../core/indexer/indexer_state.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../core/settings/settings_provider.dart';
import '../directory_picker_provider.dart';
import '../root_rejection_message.dart';
import '../widgets/library_keys_updating.dart';
import '../widgets/library_loading.dart';
import '../widgets/library_rescan_button.dart';
import '../widgets/library_sort_controls.dart';
import 'shuffle_all_button.dart';
import 'songs_empty_view.dart';
import 'songs_list_view.dart';

final _log = Logger('library');

/// The scanned library as a flat list in the saved sort, with the floating
/// rescan button. Tapping a song plays the whole list from it.
class SongsScreen extends ConsumerStatefulWidget {
  /// [pickDirectory] opens the folder picker; defaults to
  /// [directoryPickerProvider].
  const SongsScreen({super.key, this.pickDirectory});

  final DirectoryPicker? pickDirectory;

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  /// A folder is being picked or added; ignores a second click meanwhile.
  bool _choosing = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Adds a folder picked right here (no detour through the welcome screen)
  /// and scans it.
  Future<void> _chooseFolder() async {
    if (_choosing) return;
    setState(() => _choosing = true);
    final l10n = context.l10n;
    try {
      final DirectoryPicker pick =
          widget.pickDirectory ?? ref.read(directoryPickerProvider);
      final path = await pick();
      if (path == null || !mounted) return;
      final result = await ref.read(libraryRootsControllerProvider).addRoots([
        path,
      ]);
      if (!mounted) return;
      if (result.added.isEmpty) {
        _showMessage(rootRejectionsMessage(l10n, result.rejected));
        return;
      }
      // Failures land in the indexer state.
      unawaited(ref.read(libraryIndexerProvider.notifier).scan());
    } catch (error, stackTrace) {
      _log.severe('Adding a folder failed', error, stackTrace);
      if (mounted) _showMessage(l10n.libraryUnexpectedError);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasDb = ref.watch(libraryDatabaseProvider) != null;
    final hasRoots = ref.watch(libraryHasRootsProvider);
    final scanning = ref.watch(
      libraryIndexerProvider.select((s) => s is IndexerScanning),
    );

    final Widget body;
    if (!hasDb) {
      body = const SongsEmptyView(kind: SongsEmptyKind.unavailable);
    } else if (!hasRoots) {
      body = SongsEmptyView(
        kind: SongsEmptyKind.noRoots,
        onChooseFolder: _choosing ? null : _chooseFolder,
      );
    } else if (ref.watch(keysUpdatingProvider)) {
      body = const LibraryKeysUpdating();
    } else if (!ref.watch(keysReadyProvider)) {
      body = const LibraryLoading();
    } else {
      body = SongsListView(scanning: scanning);
    }

    return PageScaffold(
      title: l10n.navSongs,
      actions: [
        if (hasDb && hasRoots) ...[
          const ShuffleAllButton(),
          const SizedBox(width: 8),
          LibrarySortControls<SongSortField>(
            choice: ref.watch(settingsProvider.select((s) => s.songSort)),
            fields: SongSortField.values,
            label: songSortLabel,
            onChanged: ref.read(settingsProvider.notifier).setSongSort,
          ),
        ],
      ],
      body: LibraryRescanStack(child: body),
    );
  }
}
