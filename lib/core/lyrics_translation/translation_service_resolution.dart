import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../settings/settings_provider.dart';
import 'translation_service.dart';

/// The service a request would use right now, or `null` while that is not
/// known or none is chosen.
///
/// * `null` when no service is selected in settings;
/// * `null` while the plugin records load;
/// * `null` when reading plugin records failed or there is no library database;
/// * `null` when the stored plugin is not installed;
/// * a plugin id is itself when its translate plugin is installed.
///
/// It never writes the settings; `translationServiceSweepProvider` does.
final effectiveTranslationServiceProvider = Provider<TranslationServiceId?>((
  ref,
) {
  final stored = ref.watch(
    settingsProvider.select((s) => s.translation.service),
  );
  if (stored == null) return null;
  final records = ref.watch(translatePluginRecordsProvider);
  if (records.hasError || !records.hasValue) return null;
  final installed = records.requireValue.any(
    (r) => r.installId == stored.value,
  );
  return installed ? stored : null;
});

/// The one consent rule: [service] was not accepted yet, so nothing may be
/// sent to it. Callers pass the effective service, never a stored id that may
/// be a plugin that is gone.
bool needsNoticeFor(TranslationPrefs prefs, TranslationServiceId service) =>
    !prefs.noticeAcknowledged.contains(service);

/// Keeps the stored service and the accepted notices free of translate
/// plugins that are gone (see `SettingsNotifier.dropUninstalledTranslationServices`).
/// Acts only on records really read from the library database, so a slow
/// start, a failed read or a missing database never resets the user's choice.
/// Listen to it once for the whole session.
final translationServiceSweepProvider = Provider<void>((ref) {
  void sweep() {
    if (ref.read(libraryDatabaseProvider) == null) return;
    final records = ref.read(translatePluginRecordsProvider);
    if (records.hasError || !records.hasValue) return;
    ref.read(settingsProvider.notifier).dropUninstalledTranslationServices({
      for (final r in records.requireValue)
        ?TranslationServiceId.tryParse(r.installId),
    });
  }

  ref.listen(translatePluginRecordsProvider, (_, _) => sweep());
  // Not in the build: the settings must not change while this provider is
  // being created.
  scheduleMicrotask(() {
    if (ref.mounted) sweep();
  });
});
