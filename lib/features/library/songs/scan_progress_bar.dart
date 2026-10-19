import 'package:material_ui/material_ui.dart';

import '../../../core/indexer/indexer_state.dart';
import '../../../l10n/l10n.dart';

/// Progress of the running scan: indeterminate while files are being found,
/// determinate with "done / total" while tags are read.
class ScanProgressBar extends StatelessWidget {
  const ScanProgressBar({super.key, required this.state});

  final IndexerScanning state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reading = state.phase == ScanPhase.reading && state.total > 0;
    final label = reading
        ? l10n.libraryScanReading(state.done, state.total)
        : l10n.libraryScanDiscovering;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: reading ? state.done / state.total : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
