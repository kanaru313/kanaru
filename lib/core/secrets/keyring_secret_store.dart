import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

import 'secret_service_probe.dart';
import 'secret_store.dart';

final _log = Logger('secrets');

/// How long one keyring call may take.
const _callTimeout = Duration(seconds: 10);

/// The three calls this app makes on the keyring plugin; a fake in tests.
abstract interface class KeyringAdapter {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// [KeyringAdapter] on `flutter_secure_storage` (libsecret on Linux).
class SecureStorageKeyringAdapter implements KeyringAdapter {
  const SecureStorageKeyringAdapter([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores secrets in the system keyring.
///
/// The Linux plugin makes blocking libsecret calls on the UI thread, which a
/// Dart timeout cannot stop. So each call first asks the Secret Service over
/// D-Bus ([probe]) and the plugin is reached only when that says `ready`. If
/// a call still times out, the keyring is not used again this session.
class KeyringSecretStore implements SecretStore {
  KeyringSecretStore(
    this._adapter, {
    this._probe = probeSecretService,
    this._timeout = _callTimeout,
  });

  final KeyringAdapter _adapter;
  final Future<SecretServiceStatus> Function() _probe;
  final Duration _timeout;
  bool _dead = false;

  @override
  Future<String?> read(String key) => _guarded(() => _adapter.read(key));

  @override
  Future<void> write(String key, String value) =>
      _guarded(() => _adapter.write(key, value));

  @override
  Future<void> delete(String key) => _guarded(() => _adapter.delete(key));

  Future<T> _guarded<T>(Future<T> Function() call) async {
    if (_dead) {
      throw const SecretStoreException(
        SecretStoreFailure.unavailable,
        'keyring stopped answering earlier',
      );
    }
    switch (await _probe()) {
      case SecretServiceStatus.ready:
        break;
      case SecretServiceStatus.locked:
        throw const SecretStoreException(SecretStoreFailure.locked);
      case SecretServiceStatus.noDefaultCollection:
        throw const SecretStoreException(
          SecretStoreFailure.noDefaultCollection,
        );
      case SecretServiceStatus.absent || SecretServiceStatus.unknown:
        throw const SecretStoreException(SecretStoreFailure.unavailable);
    }
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      _dead = true;
      _log.warning('Keyring call timed out; not using it again this session');
      throw const SecretStoreException(SecretStoreFailure.timeout);
    } on Exception catch (error) {
      // PlatformException and friends: the type only, their text may name
      // what was stored.
      throw SecretStoreException(
        SecretStoreFailure.unavailable,
        error.runtimeType.toString(),
      );
    }
  }
}
