import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';

void main() {
  test('under flutter test the real data folder is never resolved', () {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    expect(container.read(lyricsPluginDataDirectoryProvider), isNull);
    expect(container.read(lyricsPluginLogDirProvider), isNull);
    expect(container.read(lyricsPluginsControllerProvider), isNull);
  });

  test('with a data folder given the log folder sits under it', () {
    final container = ProviderContainer(
      overrides: [lyricsPluginDataDirectoryProvider.overrideWithValue('/d')],
    );
    addTearDown(container.dispose);
    expect(container.read(lyricsPluginLogDirProvider)!.path, '/d/plugin-logs');
  });
}
