import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/native/file_trash.dart';

/// Moves a real file to the real trash. Skipped unless
/// `KANARU_REAL_TRASH_TEST=1`. Run it with its own `XDG_DATA_HOME`, so the
/// file lands in `$XDG_DATA_HOME/Trash` and never in the developer's trash:
///
///     KANARU_REAL_TRASH_TEST=1 XDG_DATA_HOME=/tmp/kanaru-trash-test \
///       flutter test test/core/native/file_trash_real_test.dart
void main() {
  final enabled = Platform.environment['KANARU_REAL_TRASH_TEST'] == '1';
  final dataHome = Platform.environment['XDG_DATA_HOME'];

  test(
    'a real file goes to the trash under XDG_DATA_HOME',
    () async {
      if (dataHome == null || dataHome.isEmpty) {
        fail('Set XDG_DATA_HOME to a scratch folder first');
      }
      // The source lives under the same folder, so it shares a disk with the
      // trash this test asks GLib for.
      final dir = Directory('$dataHome/source')..createSync(recursive: true);
      final file = File('${dir.path}/kanaru-real-trash-$pid.lrc')
        ..writeAsStringSync('trash me');

      final result = await GioFileTrash().trash(file.path);

      expect(result, TrashResult.trashed);
      expect(file.existsSync(), isFalse);
      final infos = Directory('$dataHome/Trash/info')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.trashinfo'))
          .map((f) => f.readAsStringSync())
          .toList();
      expect(
        infos.any((text) => text.contains('Path=${file.path}')),
        isTrue,
        reason: 'a .trashinfo records the original path',
      );
    },
    skip: enabled ? false : 'set KANARU_REAL_TRASH_TEST=1 (and XDG_DATA_HOME)',
  );
}
