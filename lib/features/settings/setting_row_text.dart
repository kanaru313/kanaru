import 'package:material_ui/material_ui.dart';

import 'settings_coming_soon_badge.dart';

/// The title and optional subtitle of a settings row. A [comingSoon] row is
/// drawn in the disabled color, with the "Coming soon" badge after the title
/// (on a line of its own when the title is long).
class SettingRowText extends StatelessWidget {
  const SettingRowText({
    super.key,
    required this.title,
    this.subtitle,
    this.comingSoon = false,
  });

  final String title;
  final String? subtitle;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = this.subtitle;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: comingSoon ? colors.onSurface.withValues(alpha: 0.38) : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (comingSoon)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [titleText, const SettingsComingSoonBadge()],
          )
        else
          titleText,
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: comingSoon
                  ? colors.onSurface.withValues(alpha: 0.38)
                  : colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
