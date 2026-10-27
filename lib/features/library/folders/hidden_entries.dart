import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Opacity of a hidden entry: visibly apart from the rest, still readable.
const hiddenEntryOpacity = 0.6;

/// [child] dimmed when [hidden]. Only the icon and the text are dimmed, never
/// the "Hidden" label, which has to stay readable.
Widget dimmedIf(bool hidden, Widget child) =>
    hidden ? Opacity(opacity: hiddenEntryOpacity, child: child) : child;

/// The small "Hidden" tag on a hidden entry.
class HiddenLabel extends StatelessWidget {
  const HiddenLabel({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.l10n.foldersHiddenLabel,
      style:
          style ??
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
