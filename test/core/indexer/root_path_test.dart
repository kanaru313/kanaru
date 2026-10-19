import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/root_path.dart';

void main() {
  group('stripTrailingSlash', () {
    test('strips slashes but keeps /', () {
      expect(stripTrailingSlash('/music/'), '/music');
      expect(stripTrailingSlash('/music//'), '/music');
      expect(stripTrailingSlash('/'), '/');
      expect(stripTrailingSlash('/music'), '/music');
    });
  });

  group('conflictWith', () {
    test('equal paths are duplicates', () {
      expect(conflictWith('/music', ['/music']), RootRejection.duplicate);
    });

    test('nesting is caught both ways', () {
      expect(conflictWith('/music/rock', ['/music']), RootRejection.nested);
      expect(conflictWith('/music', ['/music/rock']), RootRejection.nested);
      expect(conflictWith('/home', ['/']), RootRejection.nested);
    });

    test('a sibling with the same prefix is not nested', () {
      expect(conflictWith('/music2', ['/music']), isNull);
      expect(conflictWith('/music', ['/music2']), isNull);
    });

    test('% and _ are plain characters', () {
      expect(conflictWith('/a_b', ['/axb']), isNull);
      expect(conflictWith('/100%/x', ['/100%']), RootRejection.nested);
      expect(conflictWith('/100%', ['/1000']), isNull);
    });
  });

  group('canonicalizeRoot', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('root_path_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('resolves symlinks and trailing slash', () async {
      final real = Directory('${tmp.path}/real')..createSync();
      Link('${tmp.path}/link').createSync(real.path);
      final expected = await real.resolveSymbolicLinks();

      expect((await canonicalizeRoot('${tmp.path}/link/')).path, expected);
    });

    test('rejects missing paths and files', () async {
      File('${tmp.path}/f.txt').writeAsStringSync('x');

      expect(
        (await canonicalizeRoot('${tmp.path}/nope')).rejection,
        RootRejection.notFound,
      );
      expect(
        (await canonicalizeRoot('${tmp.path}/f.txt')).rejection,
        RootRejection.notDirectory,
      );
    });
  });
}
