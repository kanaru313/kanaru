import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_startup_options.dart';
import 'package:logging/logging.dart';

void main() {
  group('mpvStartupOptions', () {
    test(
      'forces libavformat with a file-only whitelist, never access-references',
      () {
        expect(mpvStartupOptions, contains(('demuxer', 'lavf')));
        expect(
          mpvStartupOptions,
          contains(('demuxer-lavf-o', 'protocol_whitelist=file')),
        );
        // Refuses media_kit's own `loadlist`, so no track would open.
        expect(
          mpvStartupOptions.map((option) => option.$1),
          isNot(contains('access-references')),
        );
      },
    );

    test('keeps gapless audio and the memory cache', () {
      expect(mpvStartupOptions, contains(('gapless-audio', 'weak')));
      expect(mpvStartupOptions, contains(('cache-on-disk', 'no')));
    });
  });

  group('applyMpvStartupOptions', () {
    late List<LogRecord> warnings;

    setUp(() {
      warnings = [];
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen(warnings.add);
      addTearDown(() {
        subscription.cancel();
        Logger.root.level = previous;
      });
    });

    test('sets every option and stays quiet when they took', () async {
      final values = <String, String>{};
      await applyMpvStartupOptions(
        setProperty: (name, value) async => values[name] = value,
        getProperty: (name) async => values[name]!,
      );

      expect(values, {for (final (n, v) in mpvStartupOptions) n: v});
      expect(warnings, isEmpty);
    });

    test('warns for a guard option that reads back different', () async {
      await applyMpvStartupOptions(
        setProperty: (_, _) async {},
        getProperty: (name) async => name == 'demuxer' ? 'auto' : '',
      );

      expect(
        warnings.map((r) => r.message).where((m) => m.contains('demuxer')),
        hasLength(2),
      );
      expect(warnings.any((r) => r.message.contains('gapless')), isFalse);
    });

    test('a failing set is logged and the others still run', () async {
      final set = <String>[];
      await applyMpvStartupOptions(
        setProperty: (name, value) async {
          set.add(name);
          if (name == 'gapless-audio') throw StateError('no');
        },
        getProperty: (name) async =>
            mpvStartupOptions.firstWhere((o) => o.$1 == name).$2,
      );

      expect(set, mpvStartupOptions.map((o) => o.$1));
      expect(warnings, hasLength(1));
    });
  });
}
