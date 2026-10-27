import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/secrets/secret_file_store.dart';
import 'package:kanaru/core/secrets/secret_service_probe.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';

import 'fakes.dart';

void main() {
  late Directory root;
  late String dataDir;
  late FakeKeyring keyring;
  var status = SecretServiceStatus.ready;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_secret_provider_');
    dataDir = '${root.path}/kanaru';
    keyring = FakeKeyring();
    status = SecretServiceStatus.ready;
  });

  tearDown(() => root.deleteSync(recursive: true));

  SecretStoreSetup setup({String? dir, Duration? timeout}) =>
      SecretStoreSetup.custom(
        probe: () async => status,
        keyring: keyring,
        dataDir: dir ?? dataDir,
        keyringTimeout: timeout,
      );

  Future<ResolvedSecretStore> resolve(SecretStoreSetup s) async {
    final container = ProviderContainer(
      overrides: [secretStoreSetupProvider.overrideWithValue(s)],
    );
    addTearDown(container.dispose);
    return container.read(secretStoreProvider.future);
  }

  test('the default is memory and does not persist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final store = await container.read(secretStoreProvider.future);
    await store.write('k', 'v');

    expect(await store.read('k'), 'v');
    expect(store.persistent, isFalse);
    expect(store.usingFallback, isFalse);
  });

  test('no Secret Service uses the file and flags the fallback', () async {
    status = SecretServiceStatus.absent;

    final store = await resolve(setup());
    await store.write('k', 'v');

    expect(store.usingFallback, isTrue);
    expect(store.persistent, isTrue);
    expect(File('$dataDir/secrets.json').existsSync(), isTrue);
    expect(keyring.calls, 0);
  });

  test('no Secret Service and no data folder uses memory', () async {
    status = SecretServiceStatus.absent;

    final store = await resolve(
      SecretStoreSetup.custom(
        probe: () async => status,
        keyring: keyring,
        dataDir: null,
      ),
    );

    expect(store.usingFallback, isTrue);
    expect(store.persistent, isFalse);
  });

  test('a ready keyring is used', () async {
    final store = await resolve(setup());
    await store.write('k', 'v');

    expect(keyring.values, {'k': 'v'});
    expect(store.usingFallback, isFalse);
    expect(File('$dataDir/secrets.json').existsSync(), isFalse);
  });

  test('locked or unknown never falls back to the file', () async {
    for (final s in [SecretServiceStatus.locked, SecretServiceStatus.unknown]) {
      status = s;
      final store = await resolve(setup());

      await expectLater(
        store.write('k', 'v'),
        throwsA(isA<SecretStoreException>()),
      );
      expect(store.usingFallback, isFalse);
    }
    expect(keyring.calls, 0);
    expect(File('$dataDir/secrets.json').existsSync(), isFalse);
  });

  test('a hung keyring times out once, then makes no more calls', () async {
    keyring.hang = true;
    final store = await resolve(
      setup(timeout: const Duration(milliseconds: 20)),
    );

    await expectLater(
      store.read('k'),
      throwsA(
        isA<SecretStoreException>().having(
          (e) => e.kind,
          'kind',
          SecretStoreFailure.timeout,
        ),
      ),
    );
    await expectLater(store.read('k'), throwsA(isA<SecretStoreException>()));

    expect(keyring.calls, 1);
  });

  test('a key only in the file moves into a ready keyring', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    final store = await resolve(setup());

    expect(await store.read('k'), 'old');

    expect(keyring.values, {'k': 'old'});
    expect(File('$dataDir/secrets.json').existsSync(), isFalse);
  });

  test('writing to the keyring drops an older file copy', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    final store = await resolve(setup());

    await store.write('k', 'new');

    expect(keyring.values, {'k': 'new'});
    expect(await SecretFileStore(dataDir).read('k'), isNull);
  });

  test('delete removes the key from both', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    keyring.values['k'] = 'new';
    final store = await resolve(setup());

    await store.delete('k');

    expect(keyring.values, isEmpty);
    expect(await SecretFileStore(dataDir).read('k'), isNull);
  });

  test('a failed pick is not retried on its own', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        secretStoreSetupProvider.overrideWithValue(
          SecretStoreSetup.custom(
            probe: () async {
              calls++;
              throw StateError('boom');
            },
            keyring: keyring,
            dataDir: dataDir,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(secretStoreProvider.future),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, 1);
  });

  test('a read that moves a file key cannot undo a delete', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    final store = await resolve(setup());

    final read = store.read('k');
    final delete = store.delete('k');
    await Future.wait([read, delete]);

    expect(keyring.values, isEmpty);
    expect(await SecretFileStore(dataDir).read('k'), isNull);
  });

  test('a read that moves a file key cannot undo a newer write', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    final store = await resolve(setup());

    final read = store.read('k');
    final write = store.write('k', 'new');
    await Future.wait([read, write]);

    expect(keyring.values, {'k': 'new'});
    expect(await SecretFileStore(dataDir).read('k'), isNull);
  });

  test('delete reports the keyring error, not a file one', () async {
    status = SecretServiceStatus.locked;
    final store = await resolve(setup());
    await Directory(dataDir).create(recursive: true);
    await File('$dataDir/secrets.json').writeAsString('{"k":"old"}');
    // Not writable: the file delete fails too.
    await Process.run('chmod', ['500', dataDir]);
    addTearDown(() => Process.run('chmod', ['700', dataDir]));

    await expectLater(
      store.delete('k'),
      throwsA(
        isA<SecretStoreException>().having(
          (e) => e.kind,
          'kind',
          SecretStoreFailure.locked,
        ),
      ),
    );
  });

  test('delete clears the file even when the keyring fails', () async {
    await SecretFileStore(dataDir).write('k', 'old');
    status = SecretServiceStatus.locked;
    final store = await resolve(setup());

    await expectLater(
      store.delete('k'),
      throwsA(
        isA<SecretStoreException>().having(
          (e) => e.kind,
          'kind',
          SecretStoreFailure.locked,
        ),
      ),
    );

    expect(await SecretFileStore(dataDir).read('k'), isNull);
  });

  test('a service without a default keyring does not use the file', () async {
    status = SecretServiceStatus.noDefaultCollection;
    final store = await resolve(setup());

    await expectLater(
      store.write('k', 'v'),
      throwsA(
        isA<SecretStoreException>().having(
          (e) => e.kind,
          'kind',
          SecretStoreFailure.noDefaultCollection,
        ),
      ),
    );

    expect(keyring.calls, 0);
    expect(File('$dataDir/secrets.json').existsSync(), isFalse);
  });
}
