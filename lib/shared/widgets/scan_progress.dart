import 'package:material_ui/material_ui.dart';

import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import 'min_busy_builder.dart';

/// Builds a rescan control from the library [scan]: [builder] gets the
/// progress to show while busy, or `null` when idle.
///
/// Busy lasts at least [MinBusyBuilder]'s minimum, so a quick scan does not
/// flash. During that hold the scan is already over; [builder] then keeps
/// getting the last progress the scan reported, never a made-up one.
class ScanProgressBuilder extends StatefulWidget {
  const ScanProgressBuilder({
    super.key,
    required this.scan,
    required this.builder,
  });

  final IndexerState scan;
  final Widget Function(BuildContext context, IndexerScanning? progress)
  builder;

  @override
  State<ScanProgressBuilder> createState() => _ScanProgressBuilderState();
}

class _ScanProgressBuilderState extends State<ScanProgressBuilder> {
  /// The latest progress seen; busy always starts with one, so it is set
  /// whenever the builder is told it is busy.
  IndexerScanning? _last;

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    if (scan is IndexerScanning) _last = scan;
    return MinBusyBuilder(
      busy: scan is IndexerScanning,
      builder: (context, busy) => widget.builder(context, busy ? _last : null),
    );
  }
}

/// Progress ring of a scan, [size] square: determinate while tags are read,
/// spinning while files are still being looked for.
class ScanProgressRing extends StatelessWidget {
  const ScanProgressRing({
    super.key,
    required this.scan,
    required this.size,
    required this.strokeWidth,
  });

  final IndexerScanning scan;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      value: scan.progress,
      strokeWidth: strokeWidth,
    ),
  );
}

/// Says how far [scan] got, for a tooltip.
String scanProgressTooltip(AppLocalizations l10n, IndexerScanning scan) =>
    scan.phase == ScanPhase.discovering
    ? l10n.libraryScanDiscovering
    : l10n.libraryScanReading(scan.done, scan.total);
