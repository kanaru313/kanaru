import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/indexer/indexer_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_progress_indicator.dart';
import '../../../shared/widgets/scan_progress.dart';

const _ringSize = 20.0;
const _ringStroke = 2.5;

Widget _button({
  required String tooltip,
  required VoidCallback? onPressed,
  required Widget child,
}) => IconButton.filledTonal(
  icon: child,
  tooltip: tooltip,
  onPressed: onPressed,
  visualDensity: VisualDensity.compact,
);

/// Round tonal button that rescans the library; it sits in the top bar. While
/// a scan runs it turns into its progress ring (determinate while tags are
/// read) and cannot be pressed; the tooltip says how far the scan got. The
/// ring stays for at least [ScanProgressBuilder]'s minimum, so a quick scan
/// does not flash. While the scan's covers are being made afterwards, it is
/// their progress ring instead, again disabled.
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
          return _button(
            tooltip: l10n.libraryCoverProgress(
              coverPassDone(covers),
              covers.total,
            ),
            onPressed: null,
            child: const CoverProgressIndicator(
              size: _ringSize,
              strokeWidth: _ringStroke,
              tooltip: false,
            ),
          );
        }
        if (progress == null) {
          return _button(
            tooltip: l10n.libraryRescan,
            onPressed: () =>
                unawaited(ref.read(libraryIndexerProvider.notifier).scan()),
            child: const Icon(AppIcons.refresh, size: _ringSize),
          );
        }
        return _button(
          tooltip: scanProgressTooltip(l10n, progress),
          onPressed: null,
          child: ScanProgressRing(
            scan: progress,
            size: _ringSize,
            strokeWidth: _ringStroke,
          ),
        );
      },
    );
  }
}
