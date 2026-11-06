import 'package:logging/logging.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
export '../../shared/lyrics_plugins/config/plugin_config_save.dart';

final _log = Logger('lyrics_sources');

/// Switches a source on or off; a failure is logged. A plugin removed
/// meanwhile answers skipped, and its row is already gone, so nothing is shown.
/// Returns whether the switch was saved.
Future<bool> setLyricsSourceOn(
  LyricsPluginsController controller,
  String id,
  bool on,
) async {
  try {
    await controller.setEnabled(id, on);
    return true;
  } catch (error, stackTrace) {
    _log.warning('Switching a lyrics source failed', error, stackTrace);
    return false;
  }
}
