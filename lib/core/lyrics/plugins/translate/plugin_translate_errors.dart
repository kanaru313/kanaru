import '../../../lyrics_translation/translation_failure.dart';
import '../../../plugin_runtime/plugin_runtime.dart';
import '../../../secrets/secret_store.dart';

/// What a finished translate run means: `null` when it ended `ok` (the
/// output is checked by the caller), else the kind of failure. The order:
///
/// 1. cancelled and busy: `server` (an update or uninstall stopped it, or
///    the pool was full; a later try may work);
/// 2. timeout: `network`;
/// 3. a script error by its kind: `auth` is `noKey` when a secret field of
///    the plugin is empty in the run's config and `badKey` otherwise;
///    `quota`, `rateLimited` and `invalidResponse` map to their namesakes;
///    `server` and no kind defer to the first failed `fetch` when there was
///    one, else `server` and `invalidResponse`;
/// 4. memory, stack, output over the limit, internal: `invalidResponse`.
///
/// Unlike for lyrics, a `fetch` the script caught is ignored when the run
/// ended `ok`: the output is checked instead, so a script that fell back to
/// another key still succeeds.
TranslationFailureKind? translateFailureKind(
  PluginRunResult result, {
  required bool hasEmptySecret,
}) => switch (result.status) {
  PluginRunStatus.ok => null,
  PluginRunStatus.cancelled ||
  PluginRunStatus.busy => TranslationFailureKind.server,
  PluginRunStatus.timeout => TranslationFailureKind.network,
  PluginRunStatus.scriptError => _fromScriptError(result, hasEmptySecret),
  PluginRunStatus.memory ||
  PluginRunStatus.stack ||
  PluginRunStatus.outputTooLarge ||
  PluginRunStatus.internal => TranslationFailureKind.invalidResponse,
};

/// The failure for a setup that went wrong: a locked or unavailable secret
/// store, a load that took too long (`network`), or a package or settings
/// that cannot be read (`invalidResponse`).
TranslationFailureKind translateSetupFailureKind({
  required bool timedOut,
  SecretStoreFailure? secret,
}) {
  if (secret != null) {
    return secret == SecretStoreFailure.locked
        ? TranslationFailureKind.keyStoreLocked
        : TranslationFailureKind.keyStoreUnavailable;
  }
  return timedOut
      ? TranslationFailureKind.network
      : TranslationFailureKind.invalidResponse;
}

TranslationFailureKind _fromScriptError(
  PluginRunResult result,
  bool hasEmptySecret,
) {
  switch (result.errorKind) {
    case PluginRunErrorKind.auth:
      return hasEmptySecret
          ? TranslationFailureKind.noKey
          : TranslationFailureKind.badKey;
    case PluginRunErrorKind.quota:
      return TranslationFailureKind.quotaExceeded;
    case PluginRunErrorKind.rateLimited:
      return TranslationFailureKind.rateLimited;
    case PluginRunErrorKind.invalidResponse:
      return TranslationFailureKind.invalidResponse;
    case PluginRunErrorKind.server:
    case PluginRunErrorKind.none:
      final fetch = result.fetchFailure;
      if (fetch != null) return _fromFetchFailure(fetch.kind);
      return result.errorKind == PluginRunErrorKind.server
          ? TranslationFailureKind.server
          : TranslationFailureKind.invalidResponse;
  }
}

TranslationFailureKind _fromFetchFailure(PluginFetchFailureKind kind) =>
    switch (kind) {
      PluginFetchFailureKind.network => TranslationFailureKind.network,
      PluginFetchFailureKind.blockedHost ||
      PluginFetchFailureKind.notConsented => TranslationFailureKind.blocked,
      PluginFetchFailureKind.rateLimited => TranslationFailureKind.rateLimited,
      PluginFetchFailureKind.invalidRequest ||
      PluginFetchFailureKind.invalidResponse =>
        TranslationFailureKind.invalidResponse,
      PluginFetchFailureKind.abandoned => TranslationFailureKind.server,
    };
