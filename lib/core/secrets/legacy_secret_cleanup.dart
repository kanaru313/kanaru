import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'secret_store.dart';

final _log = Logger('secrets');

// The API key of the removed built-in DeepL client. Nothing reads it any
// more, and the settings row that could clear it is gone, so it is deleted
// once per process. Remove with the pre-release migration collapse.
const _legacyDeeplKeySecret = 'deepl_api_key';

var _started = false;

/// Deletes secrets left by features that no longer exist, from the keyring and
/// the fallback file alike. Runs at most once per process; best effort: a
/// failure is logged by type only and ignored. Not awaited by callers.
void removeLegacySecretsOnce(SecretStore store) {
  if (_started) return;
  _started = true;
  unawaited(removeLegacySecrets(store));
}

/// The deletion itself; never throws.
Future<void> removeLegacySecrets(SecretStore store) async {
  try {
    await store.delete(_legacyDeeplKeySecret);
  } on Object catch (error) {
    _log.warning('Could not remove a legacy secret: ${error.runtimeType}');
  }
}

/// Lets a test run [removeLegacySecretsOnce] again.
@visibleForTesting
void resetLegacySecretCleanup() => _started = false;
