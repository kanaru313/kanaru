import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics_translation/translation_jobs.dart';
import '../../core/lyrics_translation/translation_service.dart';
import '../../l10n/l10n.dart';

final _log = Logger('lyrics_sources');

/// What the user is told when a config value was not saved; null when it was.
/// A locked or absent keyring is the case the user can fix, so it says how.
String? pluginConfigWriteMessage(
  AppLocalizations l10n,
  PluginConfigWrite result,
) => switch (result) {
  PluginConfigWrite.written => null,
  PluginConfigWrite.invalidValue => l10n.pluginConfigInvalidValue,
  PluginConfigWrite.tooLarge => l10n.pluginConfigTooLarge,
  PluginConfigWrite.unknownKey => l10n.pluginConfigUnknownKey,
  PluginConfigWrite.secretStoreFailed => l10n.pluginConfigSecretStoreFailed,
};

/// How a save ended: [message] says why it was refused (worded for the field
/// to show inline), null when it was saved. A [retryable] refusal came from
/// something that may pass later (the keyring, an exception); the same value
/// is worth sending again.
class PluginConfigSaveResult {
  const PluginConfigSaveResult(this.message, {this.retryable = false});

  final String? message;
  final bool retryable;

  bool get saved => message == null;
}

/// Saves one config value; see [PluginConfigSaveResult].
Future<PluginConfigSaveResult> savePluginConfigValue(
  BuildContext context,
  WidgetRef ref,
  String installId,
  String key,
  Object? value,
) {
  // Read before the await: the page may close while the save runs.
  final jobs = ref.read(translationJobsProvider.notifier);
  return savePluginConfigValueWith(
    controller: ref.read(lyricsPluginsControllerProvider),
    onSaved: () => forgetTranslationFailures(jobs, installId),
    l10n: context.l10n,
    installId: installId,
    key: key,
    value: value,
  );
}

/// A changed key or setting may fix what failed: the translations that failed
/// for this plugin are tried again from scratch. A lyrics plugin has none.
void forgetTranslationFailures(TranslationJobs jobs, String installId) {
  final id = TranslationServiceId.tryParse(installId);
  if (id == null) return;
  jobs.clearFailures(id);
}

/// Like [savePluginConfigValue] with everything it needs already in hand, so
/// a field being torn down can still save its last edit. An exception is
/// logged and reported as a failed save.
Future<PluginConfigSaveResult> savePluginConfigValueWith({
  required LyricsPluginsController? controller,
  required AppLocalizations l10n,
  required String installId,
  required String key,
  required Object? value,
  void Function()? onSaved,
}) async {
  if (controller == null) {
    return PluginConfigSaveResult(l10n.pluginConfigSaveFailed, retryable: true);
  }
  final PluginConfigWrite result;
  try {
    result = await controller.setConfigValue(installId, key, value);
  } catch (error, stackTrace) {
    _log.warning('Saving a plugin setting failed', error, stackTrace);
    return PluginConfigSaveResult(l10n.pluginConfigSaveFailed, retryable: true);
  }
  final message = pluginConfigWriteMessage(l10n, result);
  if (message == null) onSaved?.call();
  return PluginConfigSaveResult(
    message,
    retryable: result == PluginConfigWrite.secretStoreFailed,
  );
}

/// Switches a source on or off; a failure is logged. A plugin removed
/// meanwhile answers skipped, and its row is already gone, so nothing is shown.
Future<void> setLyricsSourceOn(
  LyricsPluginsController controller,
  String id,
  bool on,
) async {
  try {
    await controller.setEnabled(id, on);
  } catch (error, stackTrace) {
    _log.warning('Switching a lyrics source failed', error, stackTrace);
  }
}
