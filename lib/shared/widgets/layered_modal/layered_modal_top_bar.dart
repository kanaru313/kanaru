import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../marquee_text.dart';

/// Pause before an overflowing [LayeredModalTopBar] title starts scrolling.
const Duration _topBarMarqueeDelay = Duration(milliseconds: 1200);

/// Header bar of a child modal: a one-line [title] and a close button (`✕`)
/// that pops only the child modal and returns to the parent modal underneath.
class LayeredModalTopBar extends StatelessWidget {
  const LayeredModalTopBar({super.key, required this.title, this.onClose});

  /// Title shown in the bar.
  final String title;

  /// Called when the close button is pressed; pops the enclosing route when
  /// null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: MarqueeText(
                text: title,
                startDelay: _topBarMarqueeDelay,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.l10n.contextModalClose,
            icon: const Icon(AppIcons.close),
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
