import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'folder_watcher_provider.dart';
import 'indexer_providers.dart';

/// Work to do once the first frame is up. Returns the quiet scan's future
/// when one was started, else `null`.
///
/// - A library that already has folders counts as onboarded, so a user from
///   before the flag existed keeps skipping the source picker even after
///   removing every folder.
/// - "Rescan when Kanaru opens": scans in the background, quietly, when the
///   setting is on, the library database is available and a folder exists.
/// - "Watch folders": starts the folder watcher, which follows the setting.
Future<void>? runLibraryStartupTasks(ProviderContainer container) {
  final hasRoots = container.read(libraryHasRootsProvider);
  if (hasRoots) {
    container.read(settingsProvider.notifier).markLibraryOnboarded();
  }
  final scan =
      !hasRoots ||
          container.read(libraryDatabaseProvider) == null ||
          !container.read(settingsProvider).rescanOnStartup
      ? null
      : container.read(libraryIndexerProvider.notifier).scan(quiet: true);
  // After the scan started, so the watcher waits for its folders instead of
  // listing them a second time. Kept for the whole session, like MPRIS.
  container.listen(folderWatcherProvider, (_, _) {});
  return scan;
}
