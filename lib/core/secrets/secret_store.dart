/// Where a credential (such as the DeepL key) is kept. Credentials never go
/// to `settings.json`, the logs or the library database.
abstract interface class SecretStore {
  /// The value stored under [key], or `null` when there is none.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  /// Removes [key]; removing a missing key is not an error.
  Future<void> delete(String key);
}

/// Name under which the DeepL API key is stored.
const deeplApiKeySecret = 'deepl_api_key';

enum SecretStoreFailure {
  /// No keyring can be used (absent, not answering, or a plugin error).
  unavailable,

  /// The keyring exists but is locked; the user has to unlock it.
  locked,

  /// A Secret Service runs but has no default collection (no keyring was
  /// ever created); the user has to create one.
  noDefaultCollection,

  /// The keyring did not answer in time; it is not used again this session.
  timeout,

  /// Reading or writing the fallback file failed.
  io,
}

/// A secret store call failed. The message never includes a key or a value.
class SecretStoreException implements Exception {
  const SecretStoreException(this.kind, [this.detail]);

  final SecretStoreFailure kind;

  /// What went wrong in general terms (for the log); never a secret.
  final String? detail;

  @override
  String toString() =>
      'SecretStoreException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Keeps secrets in memory only. The default for tests, so that they never
/// reach the real keyring or data folder.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
