import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/folders/folder_disk_listing.dart';
import '../../../core/indexer/root_path.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';
import 'hidden_entries.dart';
import 'show_hidden_provider.dart';

final _log = Logger('library');

/// What a folder page that is not in the library shows: everything directly
/// in the folder on the disk, folders and audio files, by name.
class HiddenFolderData {
  const HiddenFolderData({
    required this.path,
    required this.rootPath,
    required this.folders,
    required this.files,
  });

  final String path;

  /// The music folder it lies in.
  final String rootPath;

  /// Subfolders and audio files as paths, in natural order of their names.
  final List<String> folders;
  final List<String> files;
}

/// Whether [path] is written the way the app writes folder paths: absolute,
/// no trailing slash, no empty, `.` or `..` part, no NUL. A route key can
/// carry anything, and `..` would climb out of the music folder.
bool isCleanFolderPath(String path) {
  if (!path.startsWith('/') || path.contains('\u0000')) return false;
  if (path == '/') return true;
  return path
      .substring(1)
      .split('/')
      .every((part) => part.isNotEmpty && part != '.' && part != '..');
}

/// The music folder that holds [path], or null when none does.
String? musicFolderOf(FolderTree tree, String path) {
  if (!isCleanFolderPath(path)) return null;
  for (final root in tree.roots) {
    if (isSameOrInside(root.path, path)) return root.path;
  }
  return null;
}

/// Whether [path] is its own canonical path: no symlink in it, so that a link
/// inside a music folder cannot lead the page out of it.
Future<bool> _isCanonical(String path) async {
  try {
    return await Directory(path).resolveSymbolicLinks() == path;
  } on FileSystemException {
    return false;
  }
}

/// The page of a folder that the library does not know, read from the disk:
/// null (not found) when hidden items are off, the path is outside every
/// music folder, or it is not a folder to browse. The listing is one level.
final hiddenFolderPageProvider = FutureProvider.autoDispose
    .family<HiddenFolderData?, String>((ref, path) async {
      if (!ref.watch(showHiddenFoldersProvider)) return null;
      final tree = await ref.watch(folderTreeProvider.future);
      final root = musicFolderOf(tree, path);
      if (root == null) return null;
      final List<String> excluded;
      try {
        excluded = await ref.watch(excludedFolderPathsProvider.future);
      } on Object catch (error, stackTrace) {
        _log.warning(
          'Reading the excluded folders failed; not opening $path',
          error,
          stackTrace,
        );
        return null;
      }
      if (!await _isCanonical(path)) return null;
      if (!await isBrowsableDiskFolder(path, excludedPaths: excluded)) {
        return null;
      }
      final listing = await ref.watch(
        folderDiskListingProvider((path: path, hiddenOnly: false)).future,
      );
      return HiddenFolderData(
        path: path,
        rootPath: root,
        folders: sortedByName(listing.folders),
        files: sortedByName(listing.files),
      );
    });

/// The content of a folder page.
sealed class FolderPageContent {
  const FolderPageContent();
}

/// A folder of the library.
class LibraryFolderContent extends FolderPageContent {
  const LibraryFolderContent(this.data);

  final FolderPageData data;
}

/// A folder read from the disk.
class DiskFolderContent extends FolderPageContent {
  const DiskFolderContent(this.data);

  final HiddenFolderData data;
}

/// The page at a path: the library's folder when it has one, else, with
/// hidden items on, the folder read from the disk; null when neither.
final folderPageContentProvider = Provider.autoDispose
    .family<AsyncValue<FolderPageContent?>, String>((ref, path) {
      final library = ref.watch(folderPageProvider(path));
      if (library.hasError) {
        return AsyncError(library.error!, library.stackTrace!);
      }
      final data = library.value;
      if (data != null) return AsyncData(LibraryFolderContent(data));
      if (!library.hasValue) return const AsyncLoading();
      if (!ref.watch(showHiddenFoldersProvider)) return const AsyncData(null);
      final disk = ref.watch(hiddenFolderPageProvider(path));
      if (disk.hasError) return AsyncError(disk.error!, disk.stackTrace!);
      if (!disk.hasValue) return const AsyncLoading();
      final page = disk.value;
      return AsyncData(page == null ? null : DiskFolderContent(page));
    });
