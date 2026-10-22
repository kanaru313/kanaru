import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only AppIcons references the Material Icons class', () {
    // `Icons.` not preceded by an identifier character, so `AppIcons.` and
    // `CupertinoIcons.` do not match.
    final materialIcons = RegExp(r'(?<![A-Za-z0-9_])Icons\.');
    const allowed = 'lib/shared/icons/app_icons.dart';

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart') ||
          path.startsWith('lib/src/rust/') ||
          path.startsWith('lib/l10n/app_localizations') ||
          path == allowed) {
        continue;
      }
      if (materialIcons.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppIcons instead of Material Icons. Add the icon to '
          '$allowed and reference it from there.',
    );
  });
}
