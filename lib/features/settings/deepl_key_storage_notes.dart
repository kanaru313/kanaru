import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/deepl_key_provider.dart';
import '../../core/paths/app_directories.dart';
import '../../core/secrets/secret_store_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Warnings about where the DeepL key is kept, shown under the key row: only
/// when no system keyring was found and the key sits in a file (with its real
/// path) or in memory, plus a note when that file's permissions had to be
/// tightened. Nothing while the store is still being picked or when it is the
/// keyring.
class DeepLKeyStorageNotes extends ConsumerWidget {
  const DeepLKeyStorageNotes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The key read may be what makes the store fix the file's permissions.
    ref.watch(deeplApiKeyProvider);
    final store = ref.watch(secretStoreProvider).value;
    if (store == null || !store.usingFallback) return const SizedBox.shrink();
    final l10n = context.l10n;
    final dataDir = resolveDataDirectory(Platform.environment);
    final notes = [
      if (!store.persistent || dataDir == null)
        l10n.deeplKeyFallbackMemory
      else
        l10n.deeplKeyFallbackFile('$dataDir/secrets.json'),
      if (store.modeWasFixed) l10n.deeplKeyFallbackFixed,
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.warningRounded,
            size: 18,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
