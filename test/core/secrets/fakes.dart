import 'dart:async';

import 'package:kanaru/core/secrets/keyring_secret_store.dart';

/// In-memory [KeyringAdapter] that counts calls, can fail, and can hang.
class FakeKeyring implements KeyringAdapter {
  final values = <String, String>{};
  int calls = 0;
  Object? error;
  bool hang = false;

  Future<T> _run<T>(T Function() action) {
    calls++;
    if (hang) return Completer<T>().future;
    final failure = error;
    if (failure != null) return Future<T>.error(failure);
    return Future.value(action());
  }

  @override
  Future<String?> read(String key) => _run(() => values[key]);

  @override
  Future<void> write(String key, String value) =>
      _run(() => values[key] = value);

  @override
  Future<void> delete(String key) => _run(() => values.remove(key));
}
