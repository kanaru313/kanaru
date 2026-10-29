import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_trail.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';

({String dir, int count, String? cover}) c(String dir, int count) =>
    (dir: dir, count: count, cover: null);

List<String> names(FolderTree tree, String path) => [
  for (final n in folderTrail(tree, tree.byPath[path]!)) n.name,
];

void main() {
  parentLineTests();

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

String parentLine(FolderTree tree, String path) =>
    folderParentLine(tree.byPath[path]!);

void parentLineTests() {
  group('parent line', () {
    test('a direct child of the only music folder reads its name', () {
      final tree = buildFolderTree(['/x/Library'], [c('/x/Library/Rock', 1)]);

      expect(parentLine(tree, '/x/Library/Rock'), 'Library');
    });

    test('a deeper folder reads the folders above it', () {
      final tree = buildFolderTree(['/m'], [c('/m/Việt Nam/Rock/CD 1', 1)]);

      expect(parentLine(tree, '/m/Việt Nam/Rock/CD 1'), 'Việt Nam › Rock');
    });

    test('with several music folders it leads with the music folder', () {
      final tree = buildFolderTree(
        ['/a/Music', '/b/Rock'],
        [c('/a/Music/x/y', 1), c('/b/Rock/z', 1)],
      );

      expect(parentLine(tree, '/a/Music/x/y'), 'Music › x');
      expect(parentLine(tree, '/b/Rock/z'), 'Rock');
    });

    test('a music folder reads the directory it is in', () {
      final tree = buildFolderTree(
        ['/home/me/Music'],
        [c('/home/me/Music', 1)],
      );

      expect(parentLine(tree, '/home/me/Music'), '/home/me');
    });
  });
}
