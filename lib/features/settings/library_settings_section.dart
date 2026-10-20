import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Library settings: for now only a rescan. The button is disabled while
/// the library is unavailable, has no music folder yet, or is being
/// scanned (it then shows a spinner). The result is announced by the shell.
class LibrarySettingsSection extends ConsumerWidget {
  const LibrarySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scanning = ref.watch(
      libraryIndexerProvider.select((s) => s is IndexerScanning),
    );
    final canScan =
        !scanning &&
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);

    return SettingsSection(
      title: l10n.settingsLibrary,
      children: [
        SettingRow(
          title: l10n.settingsRescanLibrary,
          control: (_) => FilledButton.tonalIcon(
            style: settingButtonStyle(),
            onPressed: canScan
                ? () => unawaited(
                    ref.read(libraryIndexerProvider.notifier).scan(),
                  )
                : null,
            icon: scanning
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(l10n.libraryRescan),
          ),
        ),
      ],
    );
  }
}
