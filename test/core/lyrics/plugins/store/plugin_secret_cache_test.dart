import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_secret_cache.dart';
import 'package:kanaru/core/secrets/secret_store.dart';

/// A store whose reads wait for the test to release them.
class _SlowStore implements SecretStore {
  final Map<String, String> values = {};
  final List<Completer<void>> gates = [];
  int reads = 0;
  bool failDelete = false;

  @override
  Future<String?> read(String key) async {
    reads++;
    final seen = values[key]; // the value as of the call, like a slow keyring
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return seen;
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw const SecretStoreException(SecretStoreFailure.locked);
    values.remove(key);
  }
}

void main() {
  late _SlowStore store;
  late PluginSecretCache cache;

  setUp(() {
    store = _SlowStore();
    cache = PluginSecretCache(() async => store);
  });

  Future<void> releaseAll() async {
    await Future<void>.delayed(Duration.zero);
    for (final gate in store.gates) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  test('a read that began before a write never caches the old value', () async {
    store.values['n'] = 'old';
    final slow = cache.read('n');
    await Future<void>.delayed(Duration.zero);
    await cache.write('n', 'new');
    await releaseAll();
    expect(await slow, 'new');
    expect(await cache.read('n'), 'new');
    expect(store.reads, 1);
  });

  test(
    'a read that began before a delete does not bring the value back',
    () async {
      store.values['n'] = 'old';
      final slow = cache.read('n');
      await Future<void>.delayed(Duration.zero);
      await cache.delete('n');
      await releaseAll();
      expect(await slow, isNull);
      expect(await cache.read('n'), isNull);
    },
  );

  test('concurrent first reads share one store call', () async {
    store.values['n'] = 'v';
    final reads = [cache.read('n'), cache.read('n'), cache.read('n')];
    await releaseAll();
    expect(await Future.wait(reads), ['v', 'v', 'v']);
    expect(store.reads, 1);
  });

  test(
    'a failed delete keeps the cached value and reports the failure',
    () async {
      store.values['n'] = 'old';
      final first = cache.read('n');
      await releaseAll();
      await first;
      store.failDelete = true;
      await expectLater(
        cache.delete('n'),
        throwsA(isA<SecretStoreException>()),
      );
      expect(await cache.read('n'), 'old');
    },
  );
}
