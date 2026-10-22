import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';

({String dir, int count}) c(String dir, int count) => (dir: dir, count: count);

void main() {
  test('makes the folders between a root and a counted folder', () {
    final tree = buildFolderTree(['/m'], [c('/m/a/b/c', 2)]);

    expect(tree.byPath.keys, containsAll(['/m', '/m/a', '/m/a/b', '/m/a/b/c']));
    expect(tree.byPath['/m/a']!.directSongs, 0);
    expect(tree.byPath['/m/a/b/c']!.directSongs, 2);
    expect(tree.byPath['/m/a/b/c']!.name, 'c');
  });

  test('counts songs and subfolders over the whole subtree', () {
    final tree = buildFolderTree(
      ['/m'],
      [
        c('/m', 1),
        c('/m/a', 2),
        c('/m/a/x', 3),
        c('/m/a/y/z', 4),
        c('/m/b', 5),
      ],
    );

    final m = tree.byPath['/m']!;
    expect((m.directSongs, m.songs, m.subfolders), (1, 15, 5));
    final a = tree.byPath['/m/a']!;
    expect((a.directSongs, a.songs, a.subfolders), (2, 9, 3));
    final y = tree.byPath['/m/a/y']!;
    expect((y.directSongs, y.songs, y.subfolders), (0, 4, 1));
    final b = tree.byPath['/m/b']!;
    expect((b.songs, b.subfolders), (5, 0));
  });

  test('lists every root, also one without songs or the only one', () {
    final tree = buildFolderTree(['/m', '/n'], [c('/m/a', 1)]);

    expect([for (final r in tree.roots) r.path], ['/m', '/n']);
    expect(tree.roots.last.songs, 0);
    expect(tree.roots.first.isRoot, isTrue);
    expect(tree.byPath['/m/a']!.isRoot, isFalse);
    expect(buildFolderTree(['/only'], []).roots.single.path, '/only');
  });

  test('puts each folder under the root that is its prefix', () {
    final tree = buildFolderTree(
      ['/m', '/mm'],
      [c('/m/a', 1), c('/mm/a', 2), c('/m', 4)],
    );

    expect(tree.byPath['/m']!.songs, 5);
    expect(tree.byPath['/mm']!.songs, 2);
    expect(tree.byPath['/mm/a']!.rootPath, '/mm');
    expect(tree.byPath['/m/a']!.rootPath, '/m');
  });

  test('leaves out folders outside every root', () {
    final tree = buildFolderTree(['/m'], [c('/gone/x', 3), c('/m/a', 1)]);

    expect(tree.byPath.containsKey('/gone/x'), isFalse);
    expect(tree.roots.single.songs, 1);
  });

  test('children come in natural order of their names', () {
    final tree = buildFolderTree(
      ['/m'],
      [c('/m/CD 10', 1), c('/m/cd 2', 1), c('/m/CD 1', 1), c('/m/Ánh', 1)],
    );

    expect(
      [for (final n in tree.roots.single.children) n.name],
      ['Ánh', 'CD 1', 'cd 2', 'CD 10'],
    );
  });

  test('the flat list holds folders with songs of their own, by label', () {
    final tree = buildFolderTree(
      ['/m'],
      [c('/m', 1), c('/m/x/CD 10', 1), c('/m/x/CD 2', 1), c('/m/b', 1)],
    );

    expect(
      [for (final n in tree.flat) n.label],
      ['b', 'm', 'x/CD 2', 'x/CD 10'],
    );
    expect(tree.flat.any((n) => n.path == '/m/x'), isFalse);
  });

  test('with several roots the labels start with the root name', () {
    final tree = buildFolderTree(
      ['/a/Music', '/b/Rock'],
      [c('/a/Music/x', 1), c('/b/Rock', 1)],
    );

    expect([for (final n in tree.flat) n.label], ['Music/x', 'Rock']);
  });
}
