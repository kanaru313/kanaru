import 'package:material_ui/material_ui.dart';

import 'context_modal_action_tile.dart';
import 'context_modal_nav.dart';
import 'context_modal_spec.dart';

/// Turns groups of actions into page body widgets, a divider between
/// non-empty groups. Callers prepend their own groups (queue, playlist
/// context) by putting them first.
List<Widget> contextModalSections(
  ContextModalNav nav,
  List<List<ContextModalAction>> sections,
) {
  final out = <Widget>[];
  for (final section in sections) {
    if (section.isEmpty) continue;
    if (out.isNotEmpty) {
      out.add(const Divider(height: 9, thickness: 1, indent: 0));
    }
    for (final action in section) {
      out.add(
        ContextModalActionTile(
          key: ValueKey('context-modal-action-${action.id}'),
          action: action,
          nav: nav,
        ),
      );
    }
  }
  return out;
}
