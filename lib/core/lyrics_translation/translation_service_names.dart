import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lyrics/plugins/lyrics_sources_provider.dart';

/// What is known about one translate plugin, for naming it on screen and in
/// the consent notice.
class TranslationPluginInfo {
  const TranslationPluginInfo({
    required this.name,
    required this.hosts,
    required this.isRemoved,
  });

  /// The name the package declares, as is.
  final String name;

  /// The hosts the plugin may reach: where the lyrics are sent.
  final List<String> hosts;

  /// The plugin is uninstalled; only its saved translations remain.
  final bool isRemoved;
}

/// Translate plugins by install id, from live and removed records alike: a
/// saved translation of an uninstalled plugin keeps its name.
final translationPluginInfosProvider =
    Provider<Map<String, TranslationPluginInfo>>((ref) {
      return Map.unmodifiable({
        for (final record in ref.watch(lyricsPluginRecordsProvider))
          if (record.kind?.isTranslation == true)
            record.installId: TranslationPluginInfo(
              name: record.name,
              hosts: record.hosts,
              isRemoved: record.isRemoved,
            ),
      });
    });
