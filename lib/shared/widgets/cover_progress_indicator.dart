import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/cover_pass_state.dart';
import '../../l10n/l10n.dart';

/// Small determinate ring while a scan's cover pass runs, with how far it
/// got in its tooltip; nothing otherwise. [gap] is left after the ring, so
/// it takes no room while hidden. With [backdrop] the ring sits on a round
/// tonal disc, so it stays visible over album art.
class CoverProgressIndicator extends ConsumerWidget {
  const CoverProgressIndicator({
    super.key,
    this.size = 20,
    this.gap = 12,
    this.backdrop = false,
  });

  final double size;
  final double gap;
  final bool backdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(coverPassProvider);
    if (pass is! CoverPassRunning) return const SizedBox.shrink();
    final done = math.min(pass.done, pass.total);
    final scheme = Theme.of(context).colorScheme;
    Widget ring = SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        value: pass.total == 0 ? null : done / pass.total,
        strokeWidth: 2.5,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
    if (backdrop) {
      ring = DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Padding(padding: const EdgeInsets.all(8), child: ring),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(end: gap),
      child: Tooltip(
        message: context.l10n.libraryCoverProgress(done, pass.total),
        child: ring,
      ),
    );
  }
}
