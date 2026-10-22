import 'package:material_ui/material_ui.dart';

import 'setting_row_text.dart';

/// A settings row for a choice of several chips, which do not fit beside the
/// title: the chips wrap below it. [comingSoon] works as on `SettingRow`:
/// disabled look, badge, and no tap or focus whatever the chips' callbacks
/// do.
class SettingsChipsRow extends StatelessWidget {
  const SettingsChipsRow({
    super.key,
    required this.title,
    required this.chips,
    this.subtitle,
    this.comingSoon = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingRowText(
              title: title,
              subtitle: subtitle,
              comingSoon: comingSoon,
            ),
            const SizedBox(height: 8),
            ExcludeFocus(
              excluding: comingSoon,
              child: IgnorePointer(
                ignoring: comingSoon,
                child: Wrap(spacing: 8, runSpacing: 8, children: chips),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
