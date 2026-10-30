import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../core/lyrics/plugins/store/plugin_config_schema_codec.dart';

/// What the config form shows when it opens.
class PluginConfigState {
  const PluginConfigState({
    this.stored = const {},
    this.savedSecrets = const {},
    this.secretsUsingFallback = false,
  });

  /// Non-secret values the user saved, by key.
  final Map<String, Object?> stored;

  /// Keys of the secret fields that hold a value. The value itself is never
  /// read back into the form.
  final Set<String> savedSecrets;

  /// The secrets sit in a plain file or in memory: no system keyring.
  final bool secretsUsingFallback;
}

/// Who the form belongs to: the plugin and the version of its record, so an
/// update (which can change the form) reads the values again.
typedef PluginConfigKey = ({String installId, int updatedAt});

/// The saved values of the plugin's form, read once per opening.
final pluginConfigStateProvider = FutureProvider.autoDispose
    .family<PluginConfigState, PluginConfigKey>((ref, key) async {
      final controller = ref.watch(lyricsPluginsControllerProvider);
      // Read, not watched: [key] already changes with the record.
      final record = ref
          .read(lyricsPluginRecordsProvider)
          .where((r) => r.installId == key.installId && !r.isRemoved)
          .firstOrNull;
      if (controller == null || record == null) {
        return const PluginConfigState();
      }
      final secretKeys = [
        for (final f in record.config)
          if (isSecretField(f)) f.key,
      ];
      final saved = <String>{};
      for (final secret in secretKeys) {
        if (await controller.hasSecret(key.installId, secret)) {
          saved.add(secret);
        }
      }
      return PluginConfigState(
        stored: await controller.storedConfig(key.installId),
        savedSecrets: saved,
        secretsUsingFallback: secretKeys.isNotEmpty
            ? await controller.secretsUsingFallback()
            : false,
      );
    });
