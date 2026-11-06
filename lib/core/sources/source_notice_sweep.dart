import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'source_plugin_records.dart';

/// Keeps the accepted source notices free of plugins that are gone (see
/// `SettingsNotifier.dropUninstalledSourceNotices`): an uninstalled plugin
/// loses its consent, so the same id never sends again without a new
/// notice. Acts only on records really read from the library database, so a
/// slow start, a failed read or a missing database never drops a consent.
/// Listen to it once for the whole session.
final sourceNoticeSweepProvider = Provider<void>((ref) {
  void sweep() {
    if (ref.read(libraryDatabaseProvider) == null) return;
    final records = ref.read(sourcePluginRecordsProvider);
    if (records.hasError || !records.hasValue) return;
    ref.read(settingsProvider.notifier).dropUninstalledSourceNotices({
      for (final r in records.requireValue) r.installId,
    });
  }

  ref.listen(sourcePluginRecordsProvider, (_, _) => sweep());
  // Not in the build: the settings must not change while this provider is
  // being created.
  scheduleMicrotask(() {
    if (ref.mounted) sweep();
  });
});
