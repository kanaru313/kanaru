import 'package:material_ui/material_ui.dart';

/// A subtle 1-pixel horizontal divider separating setting rows inside a card.
class SettingDivider extends StatelessWidget {
  const SettingDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
