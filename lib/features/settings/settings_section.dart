import 'package:material_ui/material_ui.dart';

import 'setting_divider.dart';

/// A group of settings rows under a header, wrapped in a rounded card.
/// Without a [title] there is no header, only a small spacer (for a page
/// whose title already names it).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;

    final Widget content;
    if (title == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    } else {
      content = Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SettingDivider(),
              children[i],
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title == null)
          const SizedBox(height: 8)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        content,
      ],
    );
  }
}
