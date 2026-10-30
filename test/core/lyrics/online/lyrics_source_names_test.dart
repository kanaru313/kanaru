import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';

import 'fake_lyrics_provider.dart';

class _Named extends FakeLyricsProvider {
  _Named(String id, this.name) : super(id: id);

  final String name;

  @override
  String get displayName => name;
}

void main() {
  test('names mirror the enabled sources', () {
    final container = ProviderContainer(
      overrides: [
        lyricsProvidersProvider.overrideWithValue([
          LyricsProviderRegistration(_Named('a', 'Alpha')),
          LyricsProviderRegistration(_Named('b', 'Beta')),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final names = container.read(lyricsSourceNamesProvider);

    expect(names.keys, ['a', 'b']);
    expect(names['a'], const LyricsSourceName(displayName: 'Alpha'));
    expect(names['b']!.removed, isFalse);
    expect(names['b']!.author, isNull);
  });

  test('the default list names LRCLIB and is loaded at once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(lyricsSourceNamesProvider).keys, ['lrclib']);
    expect(container.read(lyricsSourcesLoadedProvider), isTrue);
  });

  test('names are equal by value', () {
    expect(
      const LyricsSourceName(displayName: 'A', author: 'x'),
      const LyricsSourceName(displayName: 'A', author: 'x'),
    );
    expect(
      const LyricsSourceName(displayName: 'A'),
      isNot(const LyricsSourceName(displayName: 'A', removed: true)),
    );
  });

  test('a rebuild with equal names notifies nobody', () {
    final list = StateProvider<List<LyricsProviderRegistration>>(
      (ref) => [LyricsProviderRegistration(_Named('a', 'Alpha'))],
    );
    final container = ProviderContainer(
      overrides: [
        lyricsProvidersProvider.overrideWith((ref) => ref.watch(list)),
      ],
    );
    addTearDown(container.dispose);
    var notified = 0;
    container.listen(lyricsSourceNamesProvider, (_, _) => notified++);

    container.read(list.notifier).state = [
      LyricsProviderRegistration(_Named('a', 'Alpha')),
    ];
    container.read(lyricsSourceNamesProvider);
    expect(notified, 0);

    container.read(list.notifier).state = [
      LyricsProviderRegistration(_Named('a', 'Alpha 2')),
    ];
    container.read(lyricsSourceNamesProvider);
    expect(notified, 1);
  });

  group('the names map', () {
    ProviderContainer over(List<FakeLyricsProvider> providers) {
      final c = ProviderContainer(
        overrides: [
          lyricsProvidersProvider.overrideWithValue([
            for (final p in providers) LyricsProviderRegistration(p),
          ]),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is equal, with one hash code, whatever the insertion order', () {
      final ab = over([_Named('a', 'Alpha'), _Named('b', 'Beta')]);
      final ba = over([_Named('b', 'Beta'), _Named('a', 'Alpha')]);

      final first = ab.read(lyricsSourceNamesProvider);
      final second = ba.read(lyricsSourceNamesProvider);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('cannot be changed', () {
      final names = over([_Named('a', 'Alpha')])
          .read(lyricsSourceNamesProvider);

      expect(
        () => names['x'] = const LyricsSourceName(displayName: 'X'),
        throwsUnsupportedError,
      );
    });
  });
}
