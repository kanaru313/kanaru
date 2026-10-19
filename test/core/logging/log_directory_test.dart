import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_directory.dart';

void main() {
  test('uses an absolute XDG_CACHE_HOME', () {
    expect(
      resolveLogDirectory({'XDG_CACHE_HOME': '/x/cache/', 'HOME': '/home/a'}),
      '/x/cache/kanaru/logs',
    );
  });

  test('ignores a relative XDG_CACHE_HOME', () {
    expect(
      resolveLogDirectory({'XDG_CACHE_HOME': 'cache', 'HOME': '/home/a'}),
      '/home/a/.cache/kanaru/logs',
    );
  });

  test('ignores an empty XDG_CACHE_HOME', () {
    expect(
      resolveLogDirectory({'XDG_CACHE_HOME': '', 'HOME': '/home/a'}),
      '/home/a/.cache/kanaru/logs',
    );
  });

  test('falls back to HOME alone', () {
    expect(
      resolveLogDirectory({'HOME': '/home/a'}),
      '/home/a/.cache/kanaru/logs',
    );
  });

  test('is null without HOME', () {
    expect(resolveLogDirectory({}), isNull);
    expect(resolveLogDirectory({'XDG_CACHE_HOME': 'rel'}), isNull);
  });
}
