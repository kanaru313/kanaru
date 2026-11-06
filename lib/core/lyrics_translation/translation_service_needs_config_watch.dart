import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../lyrics/plugins/lyrics_plugins_provider.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart'
    show lyricsPluginRecordsProvider;
import '../lyrics/plugins/plugin_needs_config_notices.dart';
import '../settings/settings_provider.dart';
import 'translation_service.dart';

final _log = Logger('lyrics_plugins');

/// Reports a translate plugin that needs configuration right after the user
/// picked it as the translation service. Keep it alive by watching it.
///
/// Settings are loaded before the app starts (the initial state is the file's
/// contents), so the listener sees only later changes: nothing is reported at
/// startup. A pick the notice dialog cancelled never changes the service, so
/// nothing is reported for it either.
final translationServiceNeedsConfigWatchProvider = Provider<void>((ref) {
  ref.listen(settingsProvider.select((s) => s.translation.service), (
    previous,
    next,
  ) {
    if (next == null || previous == next) return;
    _report(ref, next);
  });
});

Future<void> _report(Ref ref, TranslationServiceId service) async {
  final controller = ref.read(lyricsPluginsControllerProvider);
  final record = ref
      .read(lyricsPluginRecordsProvider)
      .where((r) => r.installId == service.value && !r.isRemoved)
      .firstOrNull;
  if (controller == null || record == null) return;
  try {
    if (!await controller.needsConfig(record.installId)) return;
  } on Object catch (error) {
    // The notice is a courtesy; a store that cannot be read shows nothing.
    _log.fine('Could not check the plugin settings: ${error.runtimeType}');
    return;
  }
  // The provider may have been disposed, or the service changed again.
  if (!ref.mounted ||
      ref.read(settingsProvider).translation.service != service) {
    return;
  }
  ref
      .read(pluginNeedsConfigNoticesProvider.notifier)
      .report(record.installId, record.name, record.kind);
}
