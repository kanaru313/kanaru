import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:kanaru/core/secrets/legacy_secret_cleanup.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';

const _legacyKey = 'deepl_api_key';

/// A store whose delete always fails, as a locked keyring does.
class _ThrowingStore implements SecretStore {
  int deletes = 0;

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {
    deletes++;
    throw const SecretStoreException(SecretStoreFailure.locked, 'sk-secret');
  }
}

void main() {
  setUp(resetLegacySecretCleanup);

  test('removes the legacy key and leaves other secrets', () async {
    final store = MemorySecretStore();
    await store.write(_legacyKey, 'abc:fx');
    await store.write('plugin-key', 'keep');

    await removeLegacySecrets(store);

    expect(await store.read(_legacyKey), isNull);
    expect(await store.read('plugin-key'), 'keep');
  });

  test('a missing key is not an error', () async {
    await removeLegacySecrets(MemorySecretStore());
  });

  test('a failing store is swallowed', () async {
    final store = _ThrowingStore();

    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = previousLevel);
    final messages = <String>[];
    final sub = Logger.root.onRecord.listen((r) => messages.add(r.message));
    addTearDown(sub.cancel);

    await removeLegacySecrets(store);

    expect(store.deletes, 1);
    expect(messages.join(), contains('SecretStoreException'));
    expect(messages.join(), isNot(contains('sk-secret')));
  });

  test('runs once per process', () async {
    final store = _ThrowingStore();

    removeLegacySecretsOnce(store);
    removeLegacySecretsOnce(store);
    await pumpEventQueue();

    expect(store.deletes, 1);
  });

  test('the secret store provider starts it on first resolve', () async {
    final memory = MemorySecretStore();
    await memory.write(_legacyKey, 'abc:fx');
    final container = ProviderContainer(
      overrides: [
        secretStoreSetupProvider.overrideWithValue(
          _FixedSetup(
            ResolvedSecretStore(
              memory,
              usingFallback: false,
              persistent: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(secretStoreProvider.future);
    await pumpEventQueue();

    expect(await memory.read(_legacyKey), isNull);
  });
}

class _FixedSetup implements SecretStoreSetup {
  _FixedSetup(this.store);

  final ResolvedSecretStore store;

  @override
  Future<ResolvedSecretStore> resolve() async => store;
}
