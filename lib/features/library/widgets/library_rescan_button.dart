import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/indexer_providers.dart';
import '../../../core/indexer/indexer_state.dart';
import '../../../l10n/l10n.dart';

/// Space a scroll view leaves at its end so the [LibraryRescanButton] never
/// covers the last item.
const libraryRescanClearance = 88.0;

/// Round floating button that rescans the library. While a scan runs it
/// turns into its progress ring (determinate while tags are read) and
/// cannot be pressed; the tooltip says how far the scan got.
class LibraryRescanButton extends ConsumerWidget {
  const LibraryRescanButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(libraryIndexerProvider);

    if (scan is! IndexerScanning) {
      return FloatingActionButton(
        // Several library pages stay mounted at once.
        heroTag: null,
        tooltip: l10n.libraryRescan,
        onPressed: () =>
            unawaited(ref.read(libraryIndexerProvider.notifier).scan()),
        child: const Icon(Icons.refresh),
      );
    }
    final reading = scan.phase == ScanPhase.reading && scan.total > 0;
    return FloatingActionButton(
      heroTag: null,
      tooltip: reading
          ? l10n.libraryScanReading(scan.done, scan.total)
          : l10n.libraryScanDiscovering,
      onPressed: null,
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          value: reading ? scan.done / scan.total : null,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// [child] with the [LibraryRescanButton] floating at its bottom right, shown
/// only while the library is open and has a music folder.
class LibraryRescanStack extends ConsumerWidget {
  const LibraryRescanStack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);

    return Stack(
      children: [
        Positioned.fill(child: child),
        if (show)
          const Positioned(right: 16, bottom: 16, child: LibraryRescanButton()),
      ],
    );
  }
}
