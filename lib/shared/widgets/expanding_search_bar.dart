import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../in_page_filter.dart';
import 'in_page_search_field.dart';

/// How long the filter box takes to grow out of, or shrink back into, the
/// filter button.
const expandingSearchDuration = Duration(milliseconds: 220);

/// A bar with a filter button at its end. Opening the filter grows its box
/// leftwards out of the button over [child], which fades away, and the button
/// turns into a close button. `Ctrl+F` is wired by the page that owns the
/// controller (see `InPageFilterHost`), not here.
class ExpandingSearchBar extends StatefulWidget {
  const ExpandingSearchBar({
    super.key,
    required this.controller,
    required this.child,
    this.boxHeight,
  });

  final InPageFilterController controller;

  /// What the bar shows while the filter is closed, such as a song count.
  final Widget child;

  /// Fixed height of the open box, for a bar that sits in a row of known
  /// height and must not grow when the box opens at a large text size.
  /// `null` lets the box take the height of its text.
  final double? boxHeight;

  @override
  State<ExpandingSearchBar> createState() => _ExpandingSearchBarState();
}

class _ExpandingSearchBarState extends State<ExpandingSearchBar>
    with SingleTickerProviderStateMixin {
  final _buttonFocus = FocusNode(debugLabel: 'expanding filter button');
  late final _reveal = AnimationController(
    vsync: this,
    duration: expandingSearchDuration,
    value: widget.controller.isOpen ? 1 : 0,
  )..addStatusListener(_onRevealStatus);
  late final _curve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFilter);
  }

  @override
  void didUpdateWidget(ExpandingSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onFilter);
    widget.controller.addListener(_onFilter);
    _reveal.value = widget.controller.isOpen ? 1 : 0;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFilter);
    _curve.dispose();
    _reveal.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  /// Plays the box in or out as the filter opens or closes.
  void _onFilter() {
    if (widget.controller.isOpen) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
    setState(() {});
  }

  /// Drops the box from the tree once it has shrunk away.
  void _onRevealStatus(AnimationStatus status) {
    if (status.isDismissed) setState(() {});
  }

  /// Hands the focus back to the filter button once the box is gone.
  void _focusButton() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buttonFocus.requestFocus();
    });
  }

  void _close() {
    widget.controller.close();
    _focusButton();
  }

  /// The filter / close button. A tooltip alone gives assistive technology no
  /// name, so the wrapper names the button itself, replacing the button's own
  /// semantics so the name is announced once.
  Widget _buildButton(BuildContext context, bool open) {
    final label = open
        ? MaterialLocalizations.of(context).closeButtonTooltip
        : context.l10n.inPageSearchOpen;
    final onPressed = open ? _close : widget.controller.open;
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      selected: open,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        focusNode: _buttonFocus,
        icon: AnimatedSwitcher(
          duration: expandingSearchDuration,
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            open ? AppIcons.close : AppIcons.search,
            key: ValueKey(open),
          ),
        ),
        tooltip: label,
        onPressed: onPressed,
      ),
    );
  }

  Widget _sized(Widget box) {
    final height = widget.boxHeight;
    return height == null ? box : SizedBox(height: height, child: box);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final open = controller.isOpen;
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              // The child fades out under the box as it grows.
              FadeTransition(
                opacity: ReverseAnimation(_curve),
                child: ExcludeSemantics(
                  excluding: open,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: widget.child,
                  ),
                ),
              ),
              if (open || !_reveal.isDismissed)
                // Grows from the end, next to the button, and is shut out of
                // focus while it shrinks away.
                SizeTransition(
                  axis: Axis.horizontal,
                  alignment: AlignmentDirectional.centerEnd,
                  sizeFactor: _curve,
                  child: ExcludeFocus(
                    excluding: !open,
                    child: _sized(
                      InPageSearchBox(
                        controller: controller,
                        width: double.infinity,
                        onEscape: _focusButton,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Part of the box's tap region: a click here would otherwise unfocus
        // an empty box, which closes it before the press lands and the button
        // then opens it again.
        TextFieldTapRegion(child: _buildButton(context, open)),
      ],
    );
  }
}
