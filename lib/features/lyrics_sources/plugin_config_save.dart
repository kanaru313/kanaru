import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';

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

/// Saves one config value and reports a refusal in a snackbar. Returns
/// whether it was saved, so the field can keep its old value when not.
Future<bool> savePluginConfigValue(
  BuildContext context,
  WidgetRef ref,
  String installId,
  String key,
  Object? value,
) => savePluginConfigValueWith(
  controller: ref.read(lyricsPluginsControllerProvider),
  // Taken before the await: leaving the page meanwhile must not throw.
  messenger: ScaffoldMessenger.maybeOf(context),
  l10n: context.l10n,
  installId: installId,
  key: key,
  value: value,
);

/// Like [savePluginConfigValue] with everything it needs already in hand, so
/// a field being torn down can still save its last edit.
Future<bool> savePluginConfigValueWith({
  required LyricsPluginsController? controller,
  required ScaffoldMessengerState? messenger,
  required AppLocalizations l10n,
  required String installId,
  required String key,
  required Object? value,
}) async {
  if (controller == null) return false;
  String? message;
  try {
    message = pluginConfigWriteMessage(
      l10n,
      await controller.setConfigValue(installId, key, value),
    );
  } catch (error, stackTrace) {
    _log.warning('Saving a plugin setting failed', error, stackTrace);
    message = l10n.pluginConfigSaveFailed;
  }
  if (message == null) return true;
  if (messenger == null) {
    // Torn down with nowhere to tell the user: keep a trace.
    _log.warning('A plugin setting was not saved and nothing could show it');
  } else {
    messenger.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: message),
    );
  }
  return false;
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
