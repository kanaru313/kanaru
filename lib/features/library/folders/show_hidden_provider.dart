import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/folders/folder_disk_listing.dart';
import '../../../core/indexer/excluded_folders_controller.dart';

final _log = Logger('library');

/// Whether the Folders pages show hidden folders and files (names starting
/// with a dot). Off by default and kept only for the session; the Folders
/// page and every folder page share it.
class ShowHiddenFolders extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showHiddenFoldersProvider = NotifierProvider<ShowHiddenFolders, bool>(
  ShowHiddenFolders.new,
);

/// Which entries of a folder to read from the disk: only the ones named
/// with a leading dot (the rest comes from the library), or all of them.
typedef DiskListingKey = ({String path, bool hiddenOnly});

/// The excluded folders as paths. Fails when they cannot be read: callers
/// then show nothing from the disk instead of listing excluded folders.
final excludedFolderPathsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async => [
    for (final folder in await ref.watch(excludedFoldersProvider.future))
      folder.path,
  ],
);

/// One level of the folder at [DiskListingKey.path], read off the build and
/// disposed with its page. Folders the user excluded are left out; the
/// listing is empty when the exclusions cannot be read.
final folderDiskListingProvider = FutureProvider.autoDispose
    .family<FolderDiskListing, DiskListingKey>((ref, key) async {
      final List<String> excluded;
      try {
        excluded = await ref.watch(excludedFolderPathsProvider.future);
      } on Object catch (error, stackTrace) {
        _log.warning(
          'Reading the excluded folders failed; listing nothing',
          error,
          stackTrace,
        );
        return FolderDiskListing.empty;
      }
      return listFolderOnDisk(
        key.path,
        hiddenOnly: key.hiddenOnly,
        excludedPaths: excluded,
      );
    });
