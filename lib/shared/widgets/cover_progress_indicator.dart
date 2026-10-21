import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/cover_pass_state.dart';
import '../../l10n/l10n.dart';

/// Determinate ring while a scan's cover pass runs, with how far it got in
/// its tooltip unless [tooltip] is false; nothing otherwise.
class CoverProgressIndicator extends ConsumerWidget {
  const CoverProgressIndicator({
    super.key,
    this.size = 20,
    this.strokeWidth = 2.5,
    this.tooltip = true,
  });

  final double size;
  final double strokeWidth;
  final bool tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(coverPassProvider);
    if (pass is! CoverPassRunning) return const SizedBox.shrink();
    final done = coverPassDone(pass);
    final Widget ring = SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        value: pass.total == 0 ? null : done / pass.total,
        strokeWidth: strokeWidth,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
    if (!tooltip) return ring;
    return Tooltip(
      message: context.l10n.libraryCoverProgress(done, pass.total),
      child: ring,
    );
  }
}

/// Tracks done in [pass], never past its total.
int coverPassDone(CoverPassRunning pass) => math.min(pass.done, pass.total);
