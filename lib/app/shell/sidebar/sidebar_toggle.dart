import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Whether the wide-window sidebar is at full width (`true`) or collapsed
/// to the icon rail (`false`). Lives for the app session.
class SidebarExpanded extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarExpandedProvider = NotifierProvider<SidebarExpanded, bool>(
  SidebarExpanded.new,
);

/// Thin vertical handle at the sidebar's edge. Idle it is a straight bar;
/// on hover it bends into a chevron pointing where the sidebar will go:
/// `<` to collapse it to the icon rail, `>` to expand it again.
class SidebarToggle extends ConsumerStatefulWidget {
  const SidebarToggle({super.key});

  @override
  ConsumerState<SidebarToggle> createState() => _SidebarToggleState();
}

class _SidebarToggleState extends ConsumerState<SidebarToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(sidebarExpandedProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Tooltip(
      message: expanded ? l10n.sidebarShrink : l10n.sidebarGrow,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ref.read(sidebarExpandedProvider.notifier).toggle,
            child: SizedBox(
              width: 24,
              height: 64,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _hovered ? 1 : 0),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                builder: (context, bend, _) => CustomPaint(
                  painter: _HandlePainter(
                    bend: bend,
                    // Ends move right for `<`, left for `>`.
                    direction: expanded ? 1 : -1,
                    color: Color.lerp(
                      colors.outlineVariant,
                      colors.onSurfaceVariant,
                      bend,
                    )!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter({
    required this.bend,
    required this.direction,
    required this.color,
  });

  /// 0 = straight bar, 1 = full chevron.
  final double bend;
  final int direction;
  final Color color;

  static const _length = 32.0;
  static const _maxOffset = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final endX = center.dx + direction * _maxOffset * bend;
    final path = Path()
      ..moveTo(endX, center.dy - _length / 2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(endX, center.dy + _length / 2);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter old) =>
      old.bend != bend || old.direction != direction || old.color != color;
}
