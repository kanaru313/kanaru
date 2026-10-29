import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_trail.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';

({String dir, int count, String? cover}) c(String dir, int count) =>
    (dir: dir, count: count, cover: null);

List<String> names(FolderTree tree, String path) => [
  for (final n in folderTrail(tree, tree.byPath[path]!)) n.name,
];

void main() {
  test('a music folder is its own trail', () {
    final tree = buildFolderTree(['/m'], [c('/m', 1)]);

    expect(names(tree, '/m'), ['m']);
  });

  test('a deep folder lists every folder from the music folder', () {
    final tree = buildFolderTree(['/m'], [c('/m/a/b/c', 2)]);

    expect(names(tree, '/m/a/b/c'), ['m', 'a', 'b', 'c']);
    expect(names(tree, '/m/a'), ['m', 'a']);
  });

  test('the trail starts at the music folder the folder is in', () {
    final tree = buildFolderTree(
      ['/a/Music', '/b/Rock'],
      [c('/a/Music/x', 1), c('/b/Rock/y/z', 1)],
    );

    expect(names(tree, '/b/Rock/y/z'), ['Rock', 'y', 'z']);
    expect(names(tree, '/a/Music/x'), ['Music', 'x']);
  });

  test('a dot folder is a step like any other', () {
    final tree = buildFolderTree(['/m'], [c('/m/x/.y/z', 1)]);

    expect(names(tree, '/m/x/.y/z'), ['m', 'x', '.y', 'z']);
  });

  test('a step missing from the tree is skipped', () {
    final tree = buildFolderTree(['/m'], [c('/m/a/b', 1)]);
    final slim = FolderTree(
      byPath: {
        for (final e in tree.byPath.entries)
          if (e.key != '/m/a') e.key: e.value,
      },
      roots: tree.roots,
      flat: tree.flat,
    );

    expect(names(slim, '/m/a/b'), ['m', 'b']);
  });

  test('a folder whose music folder is not in the tree is its own trail', () {
    final tree = buildFolderTree(['/m'], [c('/m/a', 1)]);
    final slim = FolderTree(
      byPath: {'/m/a': tree.byPath['/m/a']!},
      roots: const [],
      flat: const [],
    );

    expect(names(slim, '/m/a'), ['a']);
  });
}
