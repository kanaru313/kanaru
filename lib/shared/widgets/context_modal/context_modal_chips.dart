import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'context_modal_frame_scope.dart';
import 'context_modal_nav.dart';
import 'context_modal_spec.dart';
import 'fade_edge_scroll_view.dart';

/// Height cap of the wrapped chips in a bottom sheet.
const double _sheetChipsMaxHeight = 116;

/// Left inset that lines the chips up under the row's label.
const double _chipsInset = 58;

/// The chips folded under an action. In the dialog they sit in one
/// horizontal strip (mouse wheel scrolls it sideways, edges fade); in a
/// bottom sheet they wrap onto lines inside a capped vertical scroll.
class ContextModalChipsRow extends StatelessWidget {
  const ContextModalChipsRow({
    super.key,
    required this.chips,
    required this.nav,
  });

  final ContextModalChips chips;
  final ContextModalNav nav;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final chip in chips.items)
        _Chip(label: chip.label, onTap: () => chip.onTap(nav)),
    ];
    final hidden = ScrollConfiguration.of(context).copyWith(scrollbars: false);
    if (ContextModalFrameScope.isSheetOf(context)) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _sheetChipsMaxHeight),
        child: ScrollConfiguration(
          behavior: hidden,
          child: FadeEdgeScrollView(
            builder: (controller) => SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(_chipsInset, 2, 20, 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: items),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: hidden,
        child: FadeEdgeScrollView(
          axis: Axis.horizontal,
          builder: (controller) => Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent || !controller.hasClients) {
                return;
              }
              GestureBinding.instance.pointerSignalResolver.register(event, (
                e,
              ) {
                final p = controller.position;
                final dy = (e as PointerScrollEvent).scrollDelta.dy;
                controller.jumpTo(
                  (p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent),
                );
              });
            },
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(_chipsInset, 2, 20, 10),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => items[i],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Center(child: Text(label, maxLines: 1)),
            ),
          ),
        ),
      ),
    );
  }
}
