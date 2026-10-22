import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Small "Coming soon" tag next to the title of a row whose option is shown
/// but not wired yet.
class SettingsComingSoonBadge extends StatelessWidget {
  const SettingsComingSoonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.l10n.settingsComingSoon,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
