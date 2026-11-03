import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../app_snack_bar.dart';

/// Shows the "isn't available yet" info snackbar on the nearest messenger.
void showContextModalComingSoon(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    appSnackBar(
      kind: AppSnackBarKind.info,
      title: context.l10n.contextModalComingSoonSnack,
    ),
  );
}

/// Dimmed icon button for a header action that is not built yet. Its tap
/// answers with the coming-soon snackbar and never reaches the header's own
/// tap.
class ContextModalComingSoonIconButton extends StatelessWidget {
  const ContextModalComingSoonIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Coming soon: no keyboard focus, like the coming-soon rows; the
    // hint reaches the button's own semantics node.
    return MergeSemantics(
      child: Semantics(
        hint: l10n.contextModalComingSoon,
        child: ExcludeFocus(
          child: IconButton(
            tooltip: tooltip,
            icon: Icon(icon),
            color: Theme.of(context).colorScheme.onSurfaceVariant
                .withValues(alpha: 0.38),
            onPressed: () => showContextModalComingSoon(context),
          ),
        ),
      ),
    );
  }
}
