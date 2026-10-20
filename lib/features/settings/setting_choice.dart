import 'package:material_ui/material_ui.dart';

import 'setting_row.dart';

/// One option of a [SettingChoice].
class SettingOption<T> {
  const SettingOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Picks one of a few [options]: a segmented button when there is room, a
/// dropdown when [compact].
class SettingChoice<T> extends StatelessWidget {
  const SettingChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final List<SettingOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SettingDropdown<T>(
        options: options,
        selected: selected,
        onSelected: onSelected,
        leadingIcon: options.firstWhere((o) => o.value == selected).icon,
      );
    }
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: settingButtonStyle(),
      segments: [
        for (final option in options)
          ButtonSegment(
            value: option.value,
            icon: option.icon == null ? null : Icon(option.icon),
            label: Text(option.label),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSelected(s.single),
    );
  }
}

/// Dropdown styled as tall and round as a segmented button, so both kinds of
/// control line up in the settings list. Given a bounded width (a compact
/// settings row), it fills it, so all such dropdowns are the same width;
/// otherwise it takes the width of its longest option.
class SettingDropdown<T> extends StatelessWidget {
  const SettingDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.leadingIcon,
  });

  final List<SettingOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final leadingIcon = this.leadingIcon;
    // Made outside the layout builder, so a relayout at another width (see
    // FullOrCompactControl) hands the dropdown the same objects: it refreshes
    // itself after the frame when they change, which would relayout again.
    final leading = leadingIcon == null ? null : Icon(leadingIcon, size: 18);
    final entries = [
      for (final option in options)
        DropdownMenuEntry(value: option.value, label: option.label),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<T>(
        width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
        // Rebuilt when the UI language changes, so the shown label follows it.
        // Not keyed on the value: remounting on a choice would drop keyboard
        // focus; the menu follows a new initialSelection by itself.
        key: ValueKey(Localizations.localeOf(context)),
        initialSelection: selected,
        requestFocusOnTap: false,
        enableFilter: false,
        leadingIcon: leading,
        textStyle: Theme.of(context).textTheme.labelLarge,
        inputDecorationTheme: InputDecorationThemeData(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints.tightFor(
            height: settingControlHeight,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dropdownMenuEntries: entries,
        onSelected: (value) {
          if (value != null) onSelected(value);
        },
      ),
    );
  }
}
