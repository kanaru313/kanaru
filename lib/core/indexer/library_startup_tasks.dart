import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'indexer_providers.dart';

/// Work to do once the first frame is up. Returns the quiet scan's future
/// when one was started, else `null`.
///
/// - A library that already has folders counts as onboarded, so a user from
///   before the flag existed keeps skipping the source picker even after
///   removing every folder.
/// - "Rescan when Kanaru opens": scans in the background, quietly, when the
///   setting is on, the library database is available and a folder exists.
Future<void>? runLibraryStartupTasks(ProviderContainer container) {
  final hasRoots = container.read(libraryHasRootsProvider);
  if (hasRoots) {
    container.read(settingsProvider.notifier).markLibraryOnboarded();
  }
  if (!hasRoots ||
      container.read(libraryDatabaseProvider) == null ||
      !container.read(settingsProvider).rescanOnStartup) {
    return null;
  }
  return container.read(libraryIndexerProvider.notifier).scan(quiet: true);
}
