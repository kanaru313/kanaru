import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/paths/app_directories.dart';

void main() {
  const home = {'HOME': '/home/a'};

  group('uses an absolute XDG variable', () {
    test('config', () {
      expect(
        resolveConfigDirectory({...home, 'XDG_CONFIG_HOME': '/x/config/'}),
        '/x/config/kanaru',
      );
    });

    test('data', () {
      expect(
        resolveDataDirectory({...home, 'XDG_DATA_HOME': '/x/data'}),
        '/x/data/kanaru',
      );
    });

    test('cache', () {
      expect(
        resolveCacheDirectory({...home, 'XDG_CACHE_HOME': '/x/cache//'}),
        '/x/cache/kanaru',
      );
    });
  });

  test('falls back to HOME when the variable is unset', () {
    expect(resolveConfigDirectory(home), '/home/a/.config/kanaru');
    expect(resolveDataDirectory(home), '/home/a/.local/share/kanaru');
    expect(resolveCacheDirectory(home), '/home/a/.cache/kanaru');
  });

  test('ignores an empty or relative variable', () {
    expect(
      resolveConfigDirectory({...home, 'XDG_CONFIG_HOME': ''}),
      '/home/a/.config/kanaru',
    );
    expect(
      resolveDataDirectory({...home, 'XDG_DATA_HOME': 'data'}),
      '/home/a/.local/share/kanaru',
    );
  });

  test('trims a trailing slash on HOME', () {
    expect(
      resolveDataDirectory({'HOME': '/home/a/'}),
      '/home/a/.local/share/kanaru',
    );
  });

  test('is null without a usable HOME', () {
    expect(resolveConfigDirectory({}), isNull);
    expect(resolveDataDirectory({'XDG_DATA_HOME': 'rel'}), isNull);
    expect(resolveCacheDirectory({'HOME': 'rel'}), isNull);
  });
}
