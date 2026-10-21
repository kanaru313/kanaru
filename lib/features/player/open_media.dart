import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/audio_file_types.dart';
import '../../core/indexer/walk_audio_files.dart';
import '../../core/player/player_service.dart';
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';

export '../../core/indexer/audio_file_types.dart';

/// Every regular audio file under [path], recursively, sorted by path. Walks
/// the folder on a worker isolate (the indexer's walker, so the same files
/// count as in the library) to keep the UI running on large folders. Failures
/// are skipped: an unreadable folder or a missing [path] yields no tracks.
Future<List<Track>> scanFolder(String path) async {
  final walk = await walkAudioFilesInIsolate(path);
  final paths = [for (final file in walk.files) file.path]..sort();
  return [for (final path in paths) Track.fromPath(path)];
}

/// Outcome of an open action.
enum OpenResult { cancelled, empty, opened }

/// Picks files or a folder and replaces the play queue with them. The state
/// is `true` while a folder is being scanned.
class OpenMedia extends Notifier<bool> {
  /// Bumped by every open action, so a slow folder scan that finishes after
  /// a newer action does not replace its queue.
  int _generation = 0;

  @override
  bool build() => false;

  Future<OpenResult> openFiles() async {
    final generation = _newAction();
    final files = await picker.openFiles(
      acceptedTypeGroups: [
        const picker.XTypeGroup(label: 'Audio', extensions: audioExtensions),
      ],
    );
    if (files.isEmpty || generation != _generation) {
      return OpenResult.cancelled;
    }
    return _play([
      for (final file in files)
        if (isAudioFile(file.path)) Track.fromPath(file.path),
    ]);
  }

  Future<OpenResult> openFolder() async {
    final generation = _newAction();
    final path = await picker.getDirectoryPath();
    if (path == null || generation != _generation) {
      return OpenResult.cancelled;
    }
    state = true;
    final tracks = await scanFolder(path);
    if (generation != _generation) return OpenResult.cancelled;
    state = false;
    return _play(tracks);
  }

  /// Supersedes any scan still running and hides its progress.
  int _newAction() {
    state = false;
    return ++_generation;
  }

  Future<OpenResult> _play(List<Track> tracks) async {
    if (tracks.isEmpty) return OpenResult.empty;
    await ref.read(playerServiceProvider.notifier).openTracks(tracks);
    return OpenResult.opened;
  }
}

final openMediaProvider = NotifierProvider<OpenMedia, bool>(OpenMedia.new);

/// Runs an open action from a button or menu and tells the user when the
/// pick held no audio.
Future<void> openMediaFrom(
  BuildContext context,
  WidgetRef ref, {
  required bool folder,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.playerNoAudioFound;
  final notifier = ref.read(openMediaProvider.notifier);
  final result = folder
      ? await notifier.openFolder()
      : await notifier.openFiles();
  if (result == OpenResult.empty) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// "Open files…" / "Open folder…" menu behind a button made by [builder],
/// which gets the button's tooltip and the toggle callback.
class OpenMediaMenu extends ConsumerWidget {
  const OpenMediaMenu({super.key, required this.builder});

  final Widget Function(String tooltip, VoidCallback onPressed) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.audio_file_rounded),
          onPressed: () => openMediaFrom(context, ref, folder: false),
          child: Text(l10n.playerOpenFiles),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open_rounded),
          onPressed: () => openMediaFrom(context, ref, folder: true),
          child: Text(l10n.playerOpenFolder),
        ),
      ],
      builder: (context, controller, _) => builder(
        l10n.playerOpenMenu,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
