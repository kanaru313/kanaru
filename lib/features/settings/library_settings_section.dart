import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/scan_progress.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Library settings: for now only a rescan. The button is disabled while
/// the library is unavailable, has no music folder yet, or is being
/// scanned (it then shows a progress ring). The result is announced by the
/// shell.
class LibrarySettingsSection extends ConsumerWidget {
  const LibrarySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final available =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);

    return SettingsSection(
      title: l10n.settingsLibrary,
      children: [
        SettingRow.single(
          title: l10n.settingsRescanLibrary,
          control: ScanProgressBuilder(
            scan: ref.watch(libraryIndexerProvider),
            builder: (context, progress) => _RescanButton(
              progress: progress,
              onPressed: available && progress == null
                  ? () => unawaited(
                      ref.read(libraryIndexerProvider.notifier).scan(),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// The rescan button. While a scan runs ([progress] set), its icon turns
/// into the scan's progress ring, like the library's floating rescan
/// button; the ring has the icon's size, so the row does not move. The
/// tooltip says how far the scan got.
class _RescanButton extends StatelessWidget {
  const _RescanButton({required this.progress, required this.onPressed});

  final IndexerScanning? progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = this.progress;
    if (progress == null) {
      return FilledButton.tonalIcon(
        style: settingButtonStyle(),
        onPressed: onPressed,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.libraryRescan),
      );
    }

    return Tooltip(
      message: scanProgressTooltip(l10n, progress),
      child: FilledButton.tonalIcon(
        style: settingButtonStyle(),
        onPressed: onPressed,
        icon: ScanProgressRing(scan: progress, size: 18, strokeWidth: 2),
        label: Text(l10n.libraryRescan),
      ),
    );
  }
}
