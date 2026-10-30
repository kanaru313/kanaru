import 'package:logging/logging.dart';

import '../../../secrets/secret_store.dart';

final _log = Logger('lyrics_plugins');

/// Name under which one secret config value of a plugin is kept.
String lyricsPluginSecretName(String installId, String key) =>
    'lyrics_plugin.$installId.$key';

/// Plugin secrets in front of the [SecretStore], cached in memory. The first
/// read of a name goes to the store and concurrent reads share that one call;
/// later reads are answered from memory, because a keyring call can block the
/// UI thread. A store that fails (locked, absent) makes the value read as
/// absent; one warning is logged per session, and the store is asked again
/// only after [retryAfter].
///
/// Every name has a generation that a write or delete bumps before and after
/// its store call, so a read that began earlier never caches what it got.
class PluginSecretCache {
  PluginSecretCache(
    this._store, {
    this.retryAfter = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<SecretStore> Function() _store;
  final Duration retryAfter;
  final DateTime Function() _clock;

  final Map<String, String?> _values = {};
  final Map<String, DateTime> _failedAt = {};
  final Map<String, int> _generation = {};
  final Map<String, Future<String?>> _inFlight = {};
  bool _warned = false;

  /// The secret, or null when none is stored or the store cannot be read.
  Future<String?> read(String name) {
    if (_values.containsKey(name)) return Future.value(_values[name]);
    final failed = _failedAt[name];
    if (failed != null && _clock().difference(failed) < retryAfter) {
      return Future.value();
    }
    return _inFlight[name] ??= _load(name).whenComplete(() {
      // A block body: returning the removed future would make it wait on
      // itself.
      _inFlight.remove(name);
    });
  }

  Future<String?> _load(String name) async {
    final started = _generation[name] ?? 0;
    final String? value;
    try {
      value = await (await _store()).read(name);
    } on Object catch (error) {
      _failedAt[name] = _clock();
      _warn('read', error);
      return null;
    }
    if ((_generation[name] ?? 0) != started) {
      // A write or delete ran meanwhile: what it left is newer than this.
      return _values.containsKey(name) ? _values[name] : value;
    }
    _failedAt.remove(name);
    return _values[name] = value;
  }

  /// Stores [value]. Throws what the store throws; the cache then keeps its
  /// old value.
  Future<void> write(String name, String value) async {
    _bump(name);
    try {
      await (await _store()).write(name, value);
      _failedAt.remove(name);
      _values[name] = value;
    } finally {
      _bump(name);
    }
  }

  /// Removes the secret. When the store fails the cache keeps what it had
  /// (the entry still exists) and the failure is rethrown.
  Future<void> delete(String name) async {
    _bump(name);
    try {
      await (await _store()).delete(name);
      _failedAt.remove(name);
      _values[name] = null;
    } finally {
      _bump(name);
    }
  }

  void _bump(String name) => _generation[name] = (_generation[name] ?? 0) + 1;

  void _warn(String action, Object error) {
    if (_warned) return;
    _warned = true;
    // The error type only: nothing of a key or a value.
    _log.warning(
      'Secret store not usable ($action: ${error.runtimeType}); plugin '
      'secrets read as empty until it is',
    );
  }
}
