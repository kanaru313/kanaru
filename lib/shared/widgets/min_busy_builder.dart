import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Builds with a busy flag that stays on for at least [minDuration], so a
/// task that ends almost at once does not flash its progress on and off.
///
/// When [busy] turns on, [builder] gets `true` right away. When it turns off
/// before [minDuration] has passed since it turned on, [builder] keeps
/// getting `true` until then, and `false` the moment it ends. Longer tasks
/// are reported as they are. Turning on again during that hold starts a new
/// minimum.
class MinBusyBuilder extends StatefulWidget {
  const MinBusyBuilder({
    super.key,
    required this.busy,
    this.minDuration = const Duration(milliseconds: 300),
    required this.builder,
  });

  final bool busy;
  final Duration minDuration;
  final Widget Function(BuildContext context, bool busy) builder;

  @override
  State<MinBusyBuilder> createState() => _MinBusyBuilderState();
}

class _MinBusyBuilderState extends State<MinBusyBuilder> {
  /// Runs for [MinBusyBuilder.minDuration] from the last time busy turned
  /// on; while active, the builder is told it is busy.
  Timer? _minimum;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _startMinimum();
  }

  @override
  void didUpdateWidget(MinBusyBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy) _startMinimum();
  }

  void _startMinimum() {
    _minimum?.cancel();
    _minimum = Timer(widget.minDuration, () {
      // Rebuild only if this ends the hold.
      if (mounted && !widget.busy) setState(() {});
    });
  }

  @override
  void dispose() {
    _minimum?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.busy || (_minimum?.isActive ?? false));
}
