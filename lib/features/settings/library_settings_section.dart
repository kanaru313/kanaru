import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cover_progress_indicator.dart';
import '../../shared/widgets/scan_progress.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Library settings: for now only a rescan. The button is disabled while
/// the library is unavailable, has no music folder yet, or is being
/// scanned or its covers are being made (it then shows a progress ring).
/// The result is announced by the shell.
class LibrarySettingsSection extends ConsumerWidget {
  const LibrarySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final available =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    final covers = ref.watch(coverPassProvider);

    return SettingsSection(
      title: l10n.settingsLibrary,
      children: [
        SettingRow.single(
          title: l10n.settingsRescanLibrary,
          control: ScanProgressBuilder(
            scan: ref.watch(libraryIndexerProvider),
            builder: (context, progress) => _RescanButton(
              progress: progress,
              covers: covers is CoverPassRunning ? covers : null,
              onPressed:
                  available && progress == null && covers is! CoverPassRunning
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
/// tooltip says how far the scan got. The same goes for the cover pass
/// that follows a scan ([covers] set).
class _RescanButton extends StatelessWidget {
  const _RescanButton({
    required this.progress,
    required this.covers,
    required this.onPressed,
  });

  final IndexerScanning? progress;
  final CoverPassRunning? covers;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = this.progress;
    // One line, cut short in a narrow row with large text: the button
    // keeps its fixed height.
    final label = Text(
      l10n.libraryRescan,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final covers = this.covers;
    if (progress == null && covers != null) {
      return Tooltip(
        message: l10n.libraryCoverProgress(coverPassDone(covers), covers.total),
        child: FilledButton.tonalIcon(
          style: settingButtonStyle(),
          onPressed: onPressed,
          icon: const CoverProgressIndicator(
            size: 18,
            strokeWidth: 2,
            tooltip: false,
          ),
          label: label,
        ),
      );
    }
    if (progress == null) {
      return FilledButton.tonalIcon(
        style: settingButtonStyle(),
        onPressed: onPressed,
        icon: const Icon(Icons.refresh),
        label: label,
      );
    }

    return Tooltip(
      message: scanProgressTooltip(l10n, progress),
      child: FilledButton.tonalIcon(
        style: settingButtonStyle(),
        onPressed: onPressed,
        icon: ScanProgressRing(scan: progress, size: 18, strokeWidth: 2),
        label: label,
      ),
    );
  }
}
