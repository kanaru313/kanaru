import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'keyring_secret_store.dart';
import 'secret_file_store.dart';
import 'secret_service_probe.dart';
import 'secret_store.dart';

export 'secret_store.dart';

final _log = Logger('secrets');

/// The store chosen for this session, with what the settings screen needs to
/// warn about.
class ResolvedSecretStore implements SecretStore {
  ResolvedSecretStore(
    this._store, {
    required this.usingFallback,
    required this.persistent,
    this._modeWasFixed,
  });

  final SecretStore _store;

  /// The key is kept in a plain file (or only in memory) because there is no
  /// system keyring.
  final bool usingFallback;

  /// The key survives a restart.
  final bool persistent;

  final bool Function()? _modeWasFixed;

  /// The fallback file was readable by others and has been tightened.
  bool get modeWasFixed => _modeWasFixed?.call() ?? false;

  @override
  Future<String?> read(String key) => _store.read(key);

  @override
  Future<void> write(String key, String value) => _store.write(key, value);

  @override
  Future<void> delete(String key) => _store.delete(key);
}

/// How [secretStoreProvider] builds its store. The default keeps secrets in
/// memory, so tests never reach the real keyring or data folder; `main()`
/// overrides it with [SecretStoreSetup.system].
class SecretStoreSetup {
  SecretStoreSetup.memory()
    : _resolve = (() async => ResolvedSecretStore(
        MemorySecretStore(),
        usingFallback: false,
        persistent: false,
      ));

  SecretStoreSetup.system({required String? dataDir})
    : this.custom(
        probe: probeSecretService,
        keyring: const SecureStorageKeyringAdapter(),
        dataDir: dataDir,
      );

  /// The real selection rules with injected parts, for tests.
  SecretStoreSetup.custom({
    required Future<SecretServiceStatus> Function() probe,
    required KeyringAdapter keyring,
    required String? dataDir,
    Duration? keyringTimeout,
  }) : _resolve = (() =>
           _resolveStore(probe, keyring, dataDir, keyringTimeout));

  final Future<ResolvedSecretStore> Function() _resolve;

  Future<ResolvedSecretStore> resolve() => _resolve();
}

/// No Secret Service at all: the file. Locked, unknown or timed out: never
/// the file, since a key written there would sit in plain text on a system
/// that does have a keyring.
Future<ResolvedSecretStore> _resolveStore(
  Future<SecretServiceStatus> Function() probe,
  KeyringAdapter keyring,
  String? dataDir,
  Duration? keyringTimeout,
) async {
  final status = await probe();
  final file = dataDir == null ? null : SecretFileStore(dataDir);
  if (status == SecretServiceStatus.absent) {
    _log.info('No Secret Service; the API key goes to a file or to memory');
    return file == null
        ? ResolvedSecretStore(
            MemorySecretStore(),
            usingFallback: true,
            persistent: false,
          )
        : ResolvedSecretStore(
            file,
            usingFallback: true,
            persistent: true,
            modeWasFixed: () => file.modeWasFixed,
          );
  }
  return ResolvedSecretStore(
    _KeyringWithFileCleanup(
      KeyringSecretStore(
        keyring,
        probe: probe,
        timeout: keyringTimeout ?? const Duration(seconds: 10),
      ),
      file,
    ),
    usingFallback: false,
    persistent: true,
  );
}

/// The keyring, plus the fallback file from an earlier session without a
/// keyring: a key found only there is moved into the keyring, and clearing a
/// key removes it from both.
class _KeyringWithFileCleanup implements SecretStore {
  _KeyringWithFileCleanup(this._keyring, this._file);

  final KeyringSecretStore _keyring;
  final SecretFileStore? _file;
  Future<void> _queue = Future.value();

  // One call at a time, so a read that is moving a key from the file cannot
  // write it back after a clear or a newer write.
  @override
  Future<String?> read(String key) => _serial(() async {
    final value = await _keyring.read(key);
    if (value != null) return value;
    final fromFile = await _safeFile((file) => file.read(key));
    if (fromFile == null) return null;
    try {
      await _keyring.write(key, fromFile);
      await _file?.delete(key);
    } on SecretStoreException catch (error) {
      _log.warning('Could not move the API key into the keyring: $error');
    }
    return fromFile;
  });

  @override
  Future<void> write(String key, String value) => _serial(() async {
    await _keyring.write(key, value);
    // An older copy in the file must not outlive the new one.
    await _safeFile((file) => file.delete(key));
  });

  @override
  Future<void> delete(String key) => _serial(() async {
    // Both run even if the first fails, so "clear" never leaves a copy in
    // the file because the keyring was locked. The keyring goes first: its
    // error (locked, no keyring) is the one worth showing.
    Object? failure;
    StackTrace? trace;
    for (final remove in [
      () => _keyring.delete(key),
      () async => _file?.delete(key),
    ]) {
      try {
        await remove();
      } on Object catch (error, stack) {
        failure ??= error;
        trace ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, trace!);
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<T?> _safeFile<T>(Future<T> Function(SecretFileStore file) call) async {
    final file = _file;
    if (file == null) return null;
    try {
      return await call(file);
    } on SecretStoreException catch (error) {
      _log.warning('Fallback file not usable: $error');
      return null;
    }
  }
}

final secretStoreSetupProvider = Provider<SecretStoreSetup>(
  (ref) => SecretStoreSetup.memory(),
);

/// The secret store, picked on first use: nothing at startup touches the
/// keyring. Failing to pick is retried only when the caller asks again.
final secretStoreProvider = FutureProvider<ResolvedSecretStore>(
  (ref) => ref.watch(secretStoreSetupProvider).resolve(),
  retry: (_, _) => null,
);
