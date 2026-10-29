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

/// The line under a flat folder's name: the folders above it, joined by
/// " › " (the label without its last part, which leads with the music
/// folder's name when there are several). A direct child of the only music
/// folder reads that folder's name; a music folder itself, the directory it
/// is in.
String folderParentLine(FolderNode folder) {
  if (folder.isRoot) {
    final cut = folder.path.lastIndexOf('/');
    return cut <= 0 ? '/' : folder.path.substring(0, cut);
  }
  final parts = folder.label.split('/')..removeLast();
  if (parts.isNotEmpty) return parts.join(' › ');
  final rootCut = folder.rootPath.lastIndexOf('/');
  return folder.rootPath.substring(rootCut + 1);
}
