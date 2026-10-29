import 'folder_tree.dart';

/// The folders from the music folder down to [folder], both included, for a
/// breadcrumb. A music folder gives just itself. Folders between a music
/// folder and a folder with songs are always in the tree, so the walk finds
/// every step; a step that is missing (a tree older than [folder]) is skipped.
List<FolderNode> folderTrail(FolderTree tree, FolderNode folder) {
  final root = tree.byPath[folder.rootPath];
  if (root == null) return [folder];
  final trail = [root];
  if (folder.path == root.path) return trail;
  var path = root.path;
  for (final part in folder.path.substring(root.path.length + 1).split('/')) {
    path = '$path/$part';
    final node = tree.byPath[path];
    if (node != null) trail.add(node);
  }
  return trail;
}
