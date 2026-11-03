import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/lyrics_sources_provider.dart'
    show lyricsPluginRecordsProvider;
import '../../core/lyrics/plugins/plugin_needs_config_notices.dart';
import '../../core/lyrics_translation/translation_service.dart';
import '../../core/settings/settings_provider.dart';

final _log = Logger('lyrics_plugins');

/// After the user switched a plugin on or picked it as the translation
/// service: when a required setting is empty, asks the shell to show the
/// "needs configuration" notice. Does nothing otherwise, or while the plugin
/// store is unavailable.
///
/// Takes the app's [container] (from `ProviderScope.containerOf`, before any
/// `await` of the caller) and reads everything it needs before its own first
/// `await`, so the widget that asked may be gone by the time the store answers.
Future<void> reportIfNeedsConfig(
  ProviderContainer container,
  LyricsPluginRecord record,
) async {
  final controller = container.read(lyricsPluginsControllerProvider);
  if (controller == null) return;
  final notices = container.read(pluginNeedsConfigNoticesProvider.notifier);
  final bool needs;
  try {
    needs = await controller.needsConfig(record.installId);
  } on Object catch (error) {
    // The notice is a courtesy; a store that cannot be read shows nothing.
    _log.fine('Could not check the plugin settings: ${error.runtimeType}');
    return;
  }
  if (!needs) return;
  notices.report(record.installId, record.name, record.kind);
}

/// After a translation service was picked: reports a plugin that needs
/// configuration, but only when the pick took effect (a cancelled notice
/// dialog leaves the old service, and nothing is reported).
Future<void> reportPickedServiceNeedsConfig(
  ProviderContainer container,
  TranslationServiceId service,
) async {
  if (!service.isPlugin) return;
  if (container.read(settingsProvider).translation.service != service) return;
  final record = container
      .read(lyricsPluginRecordsProvider)
      .where((r) => r.installId == service.value && !r.isRemoved)
      .firstOrNull;
  if (record != null) await reportIfNeedsConfig(container, record);
}
