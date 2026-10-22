import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/indexer_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_progress_indicator.dart';
import '../../../shared/widgets/scan_progress.dart';

/// Space a scroll view leaves at its end so the [LibraryRescanButton] never
/// covers the last item.
const libraryRescanClearance = 88.0;

/// Round floating button that rescans the library. While a scan runs it
/// turns into its progress ring (determinate while tags are read) and
/// cannot be pressed; the tooltip says how far the scan got. The ring stays
/// for at least [ScanProgressBuilder]'s minimum, so a quick scan does not
/// flash. While the scan's covers are being made afterwards, it is their
/// progress ring instead, again disabled.
class LibraryRescanButton extends ConsumerWidget {
  const LibraryRescanButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final covers = ref.watch(coverPassProvider);

    return ScanProgressBuilder(
      scan: ref.watch(libraryIndexerProvider),
      builder: (context, progress) {
        if (progress == null && covers is CoverPassRunning) {
          return FloatingActionButton(
            heroTag: null,
            tooltip: l10n.libraryCoverProgress(
              coverPassDone(covers),
              covers.total,
            ),
            onPressed: null,
            child: const CoverProgressIndicator(
              size: 24,
              strokeWidth: 3,
              tooltip: false,
            ),
          );
        }
        if (progress == null) {
          return FloatingActionButton(
            // Several library pages stay mounted at once.
            heroTag: null,
            tooltip: l10n.libraryRescan,
            onPressed: () =>
                unawaited(ref.read(libraryIndexerProvider.notifier).scan()),
            child: const Icon(AppIcons.refresh),
          );
        }
        return FloatingActionButton(
          heroTag: null,
          tooltip: scanProgressTooltip(l10n, progress),
          onPressed: null,
          child: ScanProgressRing(scan: progress, size: 24, strokeWidth: 3),
        );
      },
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
