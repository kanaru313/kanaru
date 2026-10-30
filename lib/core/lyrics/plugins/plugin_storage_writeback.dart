import 'dart:convert';

import 'package:logging/logging.dart';

import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';

final _log = Logger('lyrics_plugin');

/// Saves the storage map a finished run returned ([json]). The guarded write
/// refuses a record that was removed or updated since the run began
/// ([updatedAt] is the value the run started with); a bad or too large map
/// is dropped with a warning. Never throws.
Future<void> savePluginStorage(
  LibraryDatabase db,
  String installId,
  String json,
  int updatedAt,
) async {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return;
    final written = await db.setLyricsPluginStorage(
      installId,
      decoded,
      expectedUpdatedAt: updatedAt,
    );
    if (written == LyricsPluginWrite.tooLarge) {
      _log.warning('A plugin storage map was too large and was not saved');
    }
  } on Object catch (e) {
    _log.warning('Could not save plugin storage: ${e.runtimeType}');
  }
}
