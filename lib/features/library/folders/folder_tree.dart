import 'dart:isolate';

import '../../../shared/natural_compare.dart';

/// One folder of the library, with what it holds counted over its whole
/// subtree.
class FolderNode {
  const FolderNode({
    required this.path,
    required this.name,
    required this.rootPath,
    required this.label,
    required this.ambiguousRoot,
    required this.directSongs,
    required this.directCoverKey,
    required this.coverKey,
    required this.songs,
    required this.subfolders,
    required this.children,
  });

  /// Absolute path without a trailing `/`.
  final String path;

  /// Last part of [path] (the whole path for `/`).
  final String name;

  /// The music folder this one is in, or is.
  final String rootPath;

  /// How the flat list names it: the path below its music folder, led by the
  /// music folder's name when there are several.
  final String label;

  /// Whether another music folder has the same name as the one this is in, so
  /// that the name alone does not say which is meant.
  final bool ambiguousRoot;

  /// Songs directly in the folder.
  final int directSongs;

  /// The cover key held by the most of the songs directly in the folder; `null`
  /// when none of them has a cover. For views that show only a folder's own
  /// songs.
  final String? directCoverKey;

  /// Cover key shown for the folder in the tree: [directCoverKey], else that of
  /// the subfolder with the most songs that has one (the first in natural order
  /// on a tie). `null` when no song below has a cover.
  final String? coverKey;

  /// Songs in the folder and all folders below it.
  final int songs;

  /// Folders below it, at any depth.
  final int subfolders;

  /// Its direct subfolders, in natural order of their names.
  final List<FolderNode> children;

  bool get isRoot => path == rootPath;
}

/// The folders under the music folders.
class FolderTree {
  const FolderTree({
    required this.byPath,
    required this.roots,
    required this.flat,
  });

  static const empty = FolderTree(byPath: {}, roots: [], flat: []);

  final Map<String, FolderNode> byPath;

  /// The music folders, in the order given.
  final List<FolderNode> roots;

  /// Every folder directly holding songs, by [FolderNode.label].
  final List<FolderNode> flat;
}

class _Dir {
  _Dir(this.path, this.name, this.rootPath, this.rel);

  final String path;
  final String name;
  final String rootPath;

  /// Path below the music folder; empty for the music folder itself.
  final String rel;
  int direct = 0;
  String? cover;
  final children = <_Dir>[];
}

String _baseName(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 || slash == path.length - 1
      ? path
      : path.substring(slash + 1);
}

/// Builds the tree of [roots] from the folders holding songs, [counts] (see
/// `folderSongCounts`). A folder outside every root (one just removed) is
/// left out; folders between a root and a counted folder are made with no
/// songs of their own. Roots never nest.
FolderTree buildFolderTree(
  List<String> roots,
  List<({String dir, int count, String? cover})> counts,
) {
  final dirs = <String, _Dir>{};
  final rootDirs = <_Dir>[];
  for (final root in roots) {
    if (dirs.containsKey(root)) continue;
    final dir = _Dir(root, _baseName(root), root, '');
    dirs[root] = dir;
    rootDirs.add(dir);
  }

  for (final (:dir, :count, :cover) in counts) {
    final root = rootDirs
        .where((r) => dir == r.path || dir.startsWith('${r.path}/'))
        .firstOrNull;
    if (root == null) continue;
    var parent = root;
    // r.path ends where the next '/' separates the next folder name.
    var start = root.path.length + 1;
    while (start <= dir.length) {
      final slash = dir.indexOf('/', start);
      final end = slash < 0 ? dir.length : slash;
      final path = dir.substring(0, end);
      var child = dirs[path];
      if (child == null) {
        child = _Dir(
          path,
          dir.substring(start, end),
          root.path,
          path.substring(root.path.length + 1),
        );
        dirs[path] = child;
        parent.children.add(child);
      }
      parent = child;
      start = end + 1;
    }
    parent.direct += count;
    // Each folder is counted once, so the cover is set, the songs are added.
    parent.cover = cover;
  }

  final multiple = rootDirs.length > 1;
  final seen = <String>{};
  final sharedNames = {
    for (final root in rootDirs)
      if (!seen.add(root.name)) root.name,
  };
  final nodes = <String, FolderNode>{};
  FolderNode freeze(_Dir dir) {
    final keyed = [
      for (final child in dir.children) (naturalKey(child.name), child),
    ]..sort((a, b) => compareNaturalKeys(a.$1, b.$1));
    final children = [for (final (_, child) in keyed) freeze(child)];
    // The first of the children with the most songs wins a tie.
    FolderNode? richest;
    for (final child in children) {
      if (child.coverKey != null &&
          (richest == null || child.songs > richest.songs)) {
        richest = child;
      }
    }
    final rootName = _baseName(dir.rootPath);
    final node = FolderNode(
      path: dir.path,
      name: dir.name,
      rootPath: dir.rootPath,
      label: dir.rel.isEmpty
          ? rootName
          : multiple
          ? '$rootName/${dir.rel}'
          : dir.rel,
      ambiguousRoot: sharedNames.contains(rootName),
      directSongs: dir.direct,
      directCoverKey: dir.cover,
      coverKey: dir.cover ?? richest?.coverKey,
      songs: dir.direct + children.fold(0, (sum, c) => sum + c.songs),
      subfolders: children.fold(0, (sum, c) => sum + 1 + c.subfolders),
      children: children,
    );
    nodes[dir.path] = node;
    return node;
  }

  final rootNodes = [for (final root in rootDirs) freeze(root)];
  final keyed = [
    for (final node in nodes.values)
      if (node.directSongs > 0) (naturalKey(node.label), node),
  ]..sort((a, b) => compareNaturalKeys(a.$1, b.$1));
  return FolderTree(
    byPath: nodes,
    roots: rootNodes,
    flat: [for (final (_, node) in keyed) node],
  );
}

/// [buildFolderTree] on another isolate, for a large library. A top-level
/// function so that the closure sent over carries nothing but its arguments
/// (a database handle in the enclosing scope could not be sent).
Future<FolderTree> buildFolderTreeInIsolate(
  List<String> roots,
  List<({String dir, int count, String? cover})> counts,
) => Isolate.run(() => buildFolderTree(roots, counts));
