import 'package:material_ui/material_ui.dart';

import '../../../core/folders/folder_disk_listing.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/natural_compare.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_card.dart';
import 'folder_tree.dart';

/// Opacity of a hidden entry: visibly apart from the rest, still readable.
const hiddenEntryOpacity = 0.6;

/// [child] dimmed when [hidden]. Only the icon and the text are dimmed, never
/// the "Hidden" label, which has to stay readable.
Widget dimmedIf(bool hidden, Widget child) =>
    hidden ? Opacity(opacity: hiddenEntryOpacity, child: child) : child;

/// Whether the file or folder at [path] has a name starting with a dot.
bool isHiddenName(String path) => diskEntryName(path).startsWith('.');

/// A file name without its extension: the title of a song read from the disk.
String titleFromFileName(String path) {
  final name = diskEntryName(path);
  final dot = name.lastIndexOf('.');
  // A name that is only an extension (".mp3") keeps its text.
  return dot <= 0 ? name : name.substring(0, dot);
}

/// A queue entry for an audio file found on the disk: the title is the file
/// name without its extension, with no artist or duration.
player.Track diskTrack(String path) =>
    trackFromItem(path: path, title: titleFromFileName(path));

/// [paths] in natural order of their names.
List<String> sortedByName(Iterable<String> paths) {
  final keyed = [for (final p in paths) (naturalKey(diskEntryName(p)), p)]
    ..sort((a, b) => compareNaturalKeys(a.$1, b.$1));
  return [for (final (_, p) in keyed) p];
}

/// A folder found on the disk, as a node with no counts (the page does not
/// count songs there). [rootPath] is the music folder it lies in.
FolderNode diskFolderNode(String path, String rootPath) => FolderNode(
  path: path,
  name: diskEntryName(path),
  rootPath: rootPath,
  label: diskEntryName(path),
  ambiguousRoot: false,
  directSongs: 0,
  songs: 0,
  subfolders: 0,
  children: const [],
  hidden: true,
);

/// The small "Hidden" tag on a hidden entry.
class HiddenLabel extends StatelessWidget {
  const HiddenLabel({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.l10n.foldersHiddenLabel,
      style:
          style ??
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}

/// [child], a song row from the library, dimmed and tagged "Hidden". The row
/// is dimmed but not the tag, which sits at the bottom right, clear of the
/// duration, and is merged into the row's accessible name.
class HiddenSongMark extends StatelessWidget {
  const HiddenSongMark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Stack(
      children: [
        Opacity(opacity: hiddenEntryOpacity, child: child),
        const Positioned(
          bottom: songCardGap / 2 + 2,
          right: 32,
          child: HiddenLabel(),
        ),
      ],
    ),
  );
}

/// A song row for an audio file found on the disk, tagged "Hidden" (the tag
/// is the trailing widget, part of the row's accessible name). Right click
/// opens the queue menu.
class HiddenSongTile extends StatelessWidget {
  const HiddenSongTile({
    super.key,
    required this.path,
    required this.onTap,
    required this.onQueueAction,
  });

  final String path;
  final VoidCallback onTap;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) => QueueActionsRegion(
    onAction: onQueueAction,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: const Opacity(
        opacity: hiddenEntryOpacity,
        child: SizedBox.square(
          dimension: 40,
          child: Center(child: Icon(AppIcons.musicNoteOutlined)),
        ),
      ),
      title: Opacity(
        opacity: hiddenEntryOpacity,
        child: Text(
          titleFromFileName(path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const HiddenLabel(),
      onTap: onTap,
    ),
  );
}
