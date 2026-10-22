import 'package:material_ui/material_ui.dart';

import 'setting_choice.dart';
import 'setting_row.dart';

/// A switch row for an option that is not wired yet: shows [value], takes no
/// input. A backend that wires the option replaces this with a normal
/// `SettingRow` and a callback.
class ComingSoonSwitchRow extends StatelessWidget {
  const ComingSoonSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final bool value;

  @override
  Widget build(BuildContext context) => SettingRow.single(
    title: title,
    subtitle: subtitle,
    comingSoon: true,
    control: Switch(value: value, onChanged: null),
  );
}

/// A dropdown row for an option that is not wired yet: shows the [selected]
/// entry of [options], takes no input.
class ComingSoonDropdownRow<T> extends StatelessWidget {
  const ComingSoonDropdownRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final List<SettingOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) => SettingRow.single(
    title: title,
    subtitle: subtitle,
    comingSoon: true,
    control: SettingDropdown<T>(
      options: options,
      selected: selected,
      enabled: false,
      // Never called: a disabled dropdown opens no menu.
      onSelected: (_) {},
    ),
  );
}
