import 'dart:io';

import 'package:logging/logging.dart';

import '../indexer/audio_file_types.dart';
import '../indexer/root_path.dart';
import '../indexer/walk_audio_files.dart' show isSkippedFolder, nomediaName;

final _log = Logger('library');

/// What one folder holds on disk: the folders and the audio files directly in
/// it, as absolute paths in no particular order.
class FolderDiskListing {
  const FolderDiskListing({this.folders = const [], this.files = const []});

  static const empty = FolderDiskListing();

  final List<String> folders;
  final List<String> files;

  bool get isEmpty => folders.isEmpty && files.isEmpty;
}

/// The last part of [path].
String diskEntryName(String path) => path.substring(path.lastIndexOf('/') + 1);

/// Whether the library walk would never enter the folder at [path], apart
/// from the dot rule: trash, `lost+found`, `@eaDir`, the Windows recycle bin.
bool _isSystemFolder(String name) =>
    !name.startsWith('.') && isSkippedFolder(name);

/// Whether [path] is a folder the user left out, or inside one.
bool _isExcluded(String path, List<String> excludedPaths) =>
    excludedPaths.any((excluded) => isSameOrInside(excluded, path));

/// Whether [path] is a real folder (a symlink to one does not count) that a
/// listing may show: not user-excluded, not a system folder, no `.nomedia`.
Future<bool> isBrowsableDiskFolder(
  String path, {
  List<String> excludedPaths = const [],
}) async {
  try {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    if (_isSystemFolder(diskEntryName(path)) ||
        _isExcluded(path, excludedPaths)) {
      return false;
    }
    if (await FileSystemEntity.type('$path/$nomediaName', followLinks: false) !=
        FileSystemEntityType.notFound) {
      return false;
    }
    // A folder that cannot be read is not worth opening.
    await Directory(path).list(followLinks: false).isEmpty;
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Reads [dir] from the disk, one level only, never following a symlink.
///
/// With [hiddenOnly] only entries whose name starts with `.` are returned
/// (the rest comes from the library); without it, every entry. Folders that
/// the library walk would not enter (see [isBrowsableDiskFolder]) and files
/// that are not audio are left out, and so is every entry that cannot be
/// read. A folder that cannot be listed (missing, no permission) gives
/// [FolderDiskListing.empty]. Paths in [excludedPaths] are canonical.
Future<FolderDiskListing> listFolderOnDisk(
  String dir, {
  required bool hiddenOnly,
  List<String> excludedPaths = const [],
}) async {
  final folders = <String>[];
  final files = <String>[];
  try {
    await for (final entity in Directory(dir).list(followLinks: false)) {
      final name = diskEntryName(entity.path);
      if (hiddenOnly && !name.startsWith('.')) continue;
      try {
        // Links (to a folder or a file) are never followed or listed.
        if (entity is Directory) {
          if (await isBrowsableDiskFolder(
            entity.path,
            excludedPaths: excludedPaths,
          )) {
            folders.add(entity.path);
          }
        } else if (entity is File && isAudioFile(name)) {
          // Touches the entry: a file that cannot be stat-ed is skipped.
          await entity.stat();
          files.add(entity.path);
        }
      } on FileSystemException catch (error) {
        _log.fine('Skipped an unreadable entry in $dir: ${error.message}');
      }
    }
  } on FileSystemException catch (error, stackTrace) {
    _log.warning('Listing $dir failed', error, stackTrace);
    return FolderDiskListing.empty;
  }
  return FolderDiskListing(folders: folders, files: files);
}
