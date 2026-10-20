import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/min_busy_builder.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Library settings: for now only a rescan. The button is disabled while
/// the library is unavailable, has no music folder yet, or is being
/// scanned (it then shows a progress bar). The result is announced by the
/// shell.
class LibrarySettingsSection extends ConsumerWidget {
  const LibrarySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(libraryIndexerProvider);
    final available =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);

    return SettingsSection(
      title: l10n.settingsLibrary,
      children: [
        SettingRow(
          title: l10n.settingsRescanLibrary,
          control: (_) => MinBusyBuilder(
            busy: scan is IndexerScanning,
            builder: (context, busy) => _RescanButton(
              scan: scan,
              busy: busy,
              onPressed: available && !busy
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

/// The rescan button. While [busy], its icon and label give way to a
/// progress bar (determinate while tags are read) in the same frame, so the
/// row does not move; the tooltip says how far the scan got.
class _RescanButton extends StatelessWidget {
  const _RescanButton({
    required this.scan,
    required this.busy,
    required this.onPressed,
  });

  final IndexerState scan;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Hidden but still laid out, so the button keeps its size.
    final button = FilledButton.tonalIcon(
      style: settingButtonStyle(),
      onPressed: onPressed,
      icon: Visibility.maintain(
        visible: !busy,
        child: const Icon(Icons.refresh),
      ),
      label: Visibility.maintain(
        visible: !busy,
        child: Text(l10n.libraryRescan),
      ),
    );
    if (!busy) return button;

    final scan = this.scan;
    // Past the end of a quick scan, the bar just keeps moving.
    final reading =
        scan is IndexerScanning &&
        scan.phase == ScanPhase.reading &&
        scan.total > 0;
    return Tooltip(
      message: reading
          ? l10n.libraryScanReading(scan.done, scan.total)
          : l10n.libraryScanDiscovering,
      child: Stack(
        // A compact row gives the button a fixed width: pass it through.
        fit: StackFit.passthrough,
        children: [
          button,
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: LinearProgressIndicator(
                  value: reading ? scan.done / scan.total : null,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
