import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../app_snack_bar.dart';
import 'context_modal_chips.dart';
import 'context_modal_nav.dart';
import 'context_modal_spec.dart';

/// One row of a modal page, drawn from a [ContextModalAction].
class ContextModalActionTile extends StatefulWidget {
  const ContextModalActionTile({
    super.key,
    required this.action,
    required this.nav,
  });

  final ContextModalAction action;
  final ContextModalNav nav;

  @override
  State<ContextModalActionTile> createState() => _ContextModalActionTileState();
}

class _ContextModalActionTileState extends State<ContextModalActionTile> {
  late bool _expanded = widget.action.chips?.initiallyExpanded ?? false;

  ContextModalAction get _action => widget.action;

  VoidCallback? get _onTap {
    if (_action.comingSoon || !_action.enabled) return null;
    if (_action.chips != null) {
      return () => setState(() => _expanded = !_expanded);
    }
    final onTap = _action.onTap;
    return onTap == null ? null : () => onTap(widget.nav);
  }

  void _showComingSoon() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.info,
        title: context.l10n.contextModalComingSoonSnack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dim = _action.comingSoon || !_action.enabled;
    final fg = _action.destructive ? colors.error : colors.onSurface;
    final iconColor = _action.destructive
        ? colors.error
        : colors.onSurfaceVariant;
    final subtitle = _action.subtitle;
    final chips = _action.chips;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final turns = AnimatedRotation(
      turns: _expanded ? 0.5 : 0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      child: const Icon(AppIcons.expandMore),
    );

    final row = InkWell(
      onTap: _onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 10, 6),
          child: Row(
            children: [
              Icon(_action.icon, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(color: fg),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (_action.comingSoon)
                _Badge(label: context.l10n.contextModalComingSoon),
              for (final t in _action.trailing)
                IconButton(
                  tooltip: t.tooltip,
                  icon: Icon(t.icon, size: 20),
                  onPressed: () => t.onTap(widget.nav),
                ),
              if (chips != null) turns,
              if (_action.opensPage) const Icon(AppIcons.chevronRight),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          enabled: !dim,
          label: _action.label,
          value: subtitle,
          hint: _action.comingSoon ? context.l10n.contextModalComingSoon : null,
          excludeSemantics: _action.trailing.isEmpty,
          expanded: chips == null ? null : _expanded,
          onTap: _action.comingSoon ? _showComingSoon : _onTap,
          child: Opacity(
            opacity: dim ? 0.5 : 1,
            // Inkwell without onTap takes no focus and no Enter; the outer
            // detector still answers a pointer tap on a coming-soon row.
            child: _action.comingSoon
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showComingSoon,
                    child: row,
                  )
                : row,
          ),
        ),
        if (chips != null)
          AnimatedSize(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? ContextModalChipsRow(chips: chips, nav: widget.nav)
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
