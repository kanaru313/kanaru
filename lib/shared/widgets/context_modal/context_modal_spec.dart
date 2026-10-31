import 'package:flutter/widgets.dart';

import 'context_modal_nav.dart';

/// A small icon button at the end of an action row (for example "show in
/// folder" next to a path).
class ContextModalTrailing {
  const ContextModalTrailing({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final void Function(ContextModalNav nav) onTap;
}

/// One chip inside a [ContextModalChips] row.
class ContextModalChip {
  const ContextModalChip({required this.label, required this.onTap});

  final String label;
  final void Function(ContextModalNav nav) onTap;
}

/// Chips folded under an action; tapping the action row expands them.
class ContextModalChips {
  const ContextModalChips({
    required this.items,
    this.initiallyExpanded = false,
  });

  final List<ContextModalChip> items;
  final bool initiallyExpanded;
}

/// What one row of a modal page shows and does. Plain data: the framework
/// renders it, the caller decides what [onTap] means.
class ContextModalAction {
  const ContextModalAction({
    required this.id,
    required this.icon,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
    this.comingSoon = false,
    this.premium = false,
    this.opensPage = false,
    this.trailing = const [],
    this.chips,
    this.onTap,
  });

  /// Stable id for tests and keys.
  final String id;
  final IconData icon;
  final String label;

  /// One quiet line under the label, ellipsized.
  final String? subtitle;

  /// False dims the row and ignores taps.
  final bool enabled;

  /// Draws the row in the error color.
  final bool destructive;

  /// Dims the row, shows a badge and answers a tap with an info snackbar;
  /// keyboard activation does nothing.
  final bool comingSoon;

  /// Marks a premium feature. Kept in the spec but not drawn until licensing
  /// exists.
  final bool premium;

  /// Shows a chevron: the row opens another page.
  final bool opensPage;

  final List<ContextModalTrailing> trailing;

  /// With chips, tapping the row toggles them instead of calling [onTap].
  final ContextModalChips? chips;

  final void Function(ContextModalNav nav)? onTap;
}

/// The items a modal acts on. A song's modal holds one; multi-select holds
/// several.
class ContextModalTarget<T> {
  const ContextModalTarget(this.items);

  final List<T> items;

  /// The only item. Throws unless exactly one is held.
  T get single => items.single;

  bool get isSingle => items.length == 1;
}
