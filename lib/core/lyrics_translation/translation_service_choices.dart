import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../settings/settings_provider.dart';
import 'translation_service.dart';
import 'translation_service_resolution.dart';

/// What the service pickers (settings and the Now Playing menu) offer.
class TranslationServiceChoices {
  const TranslationServiceChoices({
    required this.services,
    required this.selected,
    required this.ready,
  });

  /// The live translate plugins. While the plugin records are not known
  /// ([ready] false) the stored plugin is listed too, so it can be shown.
  final List<TranslationServiceId> services;

  /// The service in effect; the stored one while it is not known.
  final TranslationServiceId? selected;

  /// The plugin records are read, so a pick means what it says. When false
  /// the pickers are disabled: a tap would overwrite a stored plugin choice
  /// that cannot be checked yet.
  final bool ready;
}

/// The one list the service pickers use. A stored plugin that is gone shows
/// `null` without a write; while the records load or cannot be read, the
/// stored plugin shows and nothing can be picked.
final translationServiceChoicesProvider = Provider<TranslationServiceChoices>((
  ref,
) {
  final stored = ref.watch(
    settingsProvider.select((s) => s.translation.service),
  );
  final effective = ref.watch(effectiveTranslationServiceProvider);
  final records = ref.watch(translatePluginRecordsProvider);
  final ready = records.hasValue && !records.hasError;
  final live = records.value ?? const [];
  final services = [
    for (final record in live) ?TranslationServiceId.tryParse(record.installId),
  ];
  if (!ready) {
    return TranslationServiceChoices(
      services: [
        ...services,
        if (stored != null && !services.contains(stored)) stored,
      ],
      selected: stored,
      ready: false,
    );
  }
  return TranslationServiceChoices(
    services: services,
    selected: effective,
    ready: true,
  );
});
