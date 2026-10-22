import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_relative_path.dart';

void main() {
  test('relative paths between canonical folders and files', () {
    for (final (from, to, expected) in [
      ('/a/b', '/a/b/c.mp3', 'c.mp3'),
      ('/a/b', '/a/b/sub/c.mp3', 'sub/c.mp3'),
      ('/a/b', '/a/x/c.mp3', '../x/c.mp3'),
      ('/', '/m/c.mp3', 'm/c.mp3'),
      ('/a/b/c', '/d.mp3', '../../../d.mp3'),
      ('/a/b', '/a/b.mp3', '../b.mp3'),
      // A folder named like the file's folder prefix is not shared.
      ('/m/Live', '/m/Live Albums/a.mp3', '../Live Albums/a.mp3'),
    ]) {
      expect(
        relativePath(from: from, to: to),
        expected,
        reason: '$from → $to',
      );
    }
  });
}
