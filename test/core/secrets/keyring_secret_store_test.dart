import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/secrets/keyring_secret_store.dart';
import 'package:kanaru/core/secrets/secret_service_probe.dart';
import 'package:kanaru/core/secrets/secret_store.dart';

import 'fakes.dart';

void main() {
  test('a ready keyring passes calls to the adapter', () async {
    final adapter = FakeKeyring();
    final store = KeyringSecretStore(
      adapter,
      probe: () async => SecretServiceStatus.ready,
    );

    await store.write('k', 'v');
    expect(await store.read('k'), 'v');
    await store.delete('k');

    expect(await store.read('k'), isNull);
  });

  test('PlatformException becomes unavailable without its text', () async {
    final adapter = FakeKeyring()
      ..error = PlatformException(code: 'x', message: 'value=top-secret');
    final store = KeyringSecretStore(
      adapter,
      probe: () async => SecretServiceStatus.ready,
    );

    await expectLater(
      store.write('k', 'top-secret'),
      throwsA(
        isA<SecretStoreException>()
            .having((e) => e.kind, 'kind', SecretStoreFailure.unavailable)
            .having((e) => e.toString(), 'text', isNot(contains('top-secret'))),
      ),
    );
  });

  test('locked and unknown never reach the adapter', () async {
    final adapter = FakeKeyring();
    for (final (status, kind) in [
      (SecretServiceStatus.locked, SecretStoreFailure.locked),
      (
        SecretServiceStatus.noDefaultCollection,
        SecretStoreFailure.noDefaultCollection,
      ),
      (SecretServiceStatus.unknown, SecretStoreFailure.unavailable),
      (SecretServiceStatus.absent, SecretStoreFailure.unavailable),
    ]) {
      final store = KeyringSecretStore(adapter, probe: () async => status);
      await expectLater(
        store.read('k'),
        throwsA(
          isA<SecretStoreException>().having((e) => e.kind, 'kind', kind),
        ),
      );
    }
    expect(adapter.calls, 0);
  });

  test('a call that never returns times out and kills the keyring', () async {
    final adapter = FakeKeyring()..hang = true;
    final store = KeyringSecretStore(
      adapter,
      probe: () async => SecretServiceStatus.ready,
      timeout: const Duration(milliseconds: 20),
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
    expect(adapter.calls, 1);

    await expectLater(
      store.read('k'),
      throwsA(
        isA<SecretStoreException>().having(
          (e) => e.kind,
          'kind',
          SecretStoreFailure.unavailable,
        ),
      ),
    );
    expect(adapter.calls, 1);
  });
}
