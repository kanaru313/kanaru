import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

final _def = TranslationServiceId.tryParse('plugin-aaaaaaaaaaaa')!;
final _own = TranslationServiceId.tryParse('plugin-bbbbbbbbbbbb')!;
final _queue = TranslationServiceId.tryParse('plugin-cccccccccccc')!;

TranslationChoice _resolve({
  TranslationServiceId? defaultService,
  int? allChosenAt,
  ScopedTranslationChoice? song,
  ScopedTranslationChoice? queue,
  Set<TranslationServiceId>? live,
}) => resolveTranslationChoice(
  defaultService: defaultService,
  allChosenAt: allChosenAt,
  live: live ?? {_def, _own, _queue},
  song: song,
  queue: queue,
);

ScopedTranslationChoice _song(int? at, {Map<String, String> tune = const {}}) =>
    ScopedTranslationChoice(service: _own, tune: tune, chosenAt: at);

void main() {
  group('song against the default', () {
    // allChosenAt x song.chosenAt: only a strictly newer song choice wins.
    final cases = <(String, int?, int?, TranslationScope)>[
      ('default never stamped, song stamped', null, 5, TranslationScope.song),
      ('song newer', 5, 6, TranslationScope.song),
      ('song older', 6, 5, TranslationScope.all),
      ('equal stamps: the broader tier wins', 5, 5, TranslationScope.all),
      ('neither stamped', null, null, TranslationScope.all),
      ('song unstamped, default stamped', 5, null, TranslationScope.all),
    ];
    for (final (name, all, song, scope) in cases) {
      test(name, () {
        final choice = _resolve(
          defaultService: _def,
          allChosenAt: all,
          song: _song(song),
        );
        expect(choice.scope, scope);
        expect(choice.service, scope == TranslationScope.song ? _own : _def);
        expect(choice.defaultService, _def);
      });
    }
  });

  test('a song choice whose plugin is not installed is absent', () {
    final choice = _resolve(
      defaultService: _def,
      allChosenAt: 1,
      song: _song(9),
      live: {_def},
    );
    expect(choice.scope, TranslationScope.all);
    expect(choice.service, _def);
  });

  test('a default whose plugin is not installed gives no service', () {
    final choice = _resolve(defaultService: _def, allChosenAt: 1, live: {_own});
    expect(choice.service, isNull);
    expect(choice.defaultService, isNull);
    // A newer song choice still resolves on its own.
    final own = _resolve(
      defaultService: _def,
      allChosenAt: 1,
      song: _song(2),
      live: {_own},
    );
    expect(own.service, _own);
    expect(own.defaultService, isNull);
  });

  test('no default and no choices: no service', () {
    final choice = _resolve();
    expect(choice.service, isNull);
    expect(choice.scope, TranslationScope.all);
  });

  test('the tune of the winning tier is kept, none for the default', () {
    final tune = {'model': 'm', 'style': 's'};
    expect(
      _resolve(
        defaultService: _def,
        song: _song(3, tune: tune),
      ).tune,
      tune,
    );
    expect(
      _resolve(
        defaultService: _def,
        allChosenAt: 9,
        song: _song(3, tune: tune),
      ).tune,
      isEmpty,
    );
  });

  group('queue tier', () {
    ScopedTranslationChoice queue(int? at) =>
        ScopedTranslationChoice(service: _queue, chosenAt: at);

    test('queue newer than the default wins', () {
      final c = _resolve(defaultService: _def, allChosenAt: 1, queue: queue(2));
      expect((c.scope, c.service), (TranslationScope.queue, _queue));
    });

    test('queue equal to the default loses', () {
      final c = _resolve(defaultService: _def, allChosenAt: 2, queue: queue(2));
      expect(c.scope, TranslationScope.all);
    });

    test('song must beat both the default and the queue', () {
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 1,
          song: _song(5),
          queue: queue(6),
        ).scope,
        TranslationScope.queue,
      );
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 1,
          song: _song(7),
          queue: queue(6),
        ).scope,
        TranslationScope.song,
      );
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 1,
          song: _song(6),
          queue: queue(6),
        ).scope,
        TranslationScope.queue,
      );
    });

    test('a queue with no stamp loses to any stamped default', () {
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 0,
          queue: queue(null),
        ).scope,
        TranslationScope.all,
      );
    });

    test('a stamped queue beats a default that was never stamped', () {
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: null,
          queue: queue(0),
        ).scope,
        TranslationScope.queue,
      );
    });

    test('a newer default beats the queue and an older song', () {
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 9,
          song: _song(5),
          queue: queue(6),
        ).scope,
        TranslationScope.all,
      );
    });

    test('a song newer than the queue wins even when the queue is newer than '
        'the default', () {
      final c = _resolve(
        defaultService: _def,
        allChosenAt: 1,
        song: _song(8),
        queue: queue(7),
      );
      expect((c.scope, c.service), (TranslationScope.song, _own));
    });

    test('an absent queue plugin does not block the song', () {
      expect(
        _resolve(
          defaultService: _def,
          allChosenAt: 1,
          song: _song(5),
          queue: queue(9),
          live: {_def, _own},
        ).scope,
        TranslationScope.song,
      );
    });
  });

  test('choices are equal by content, tune included', () {
    expect(_song(3, tune: {'model': 'm'}), _song(3, tune: {'model': 'm'}));
    expect(
      _song(3, tune: {'model': 'm'}).hashCode,
      _song(3, tune: {'model': 'm'}).hashCode,
    );
    expect(_song(3, tune: {'model': 'm'}), isNot(_song(3)));
    final a = _resolve(
      defaultService: _def,
      song: _song(3, tune: {'a': 'b'}),
    );
    final b = _resolve(
      defaultService: _def,
      song: _song(3, tune: {'a': 'b'}),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(_resolve(defaultService: _def, allChosenAt: 4, song: _song(3))),
    );
  });
}
