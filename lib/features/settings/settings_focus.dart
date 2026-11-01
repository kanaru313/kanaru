import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../shared/settings_routes.dart';

/// Wait between scrolling to a link's target and pulsing it. It outlasts the
/// slides that can still be running when the link is followed (Now Playing
/// closing, the branch switch, the page slide-in, a sub-page popping), so the
/// pulse is never hidden by one of them.
const settingsFocusSettleDelay = Duration(milliseconds: 500);

/// Length of the pulse with animations on.
const settingsFocusPulseDuration = Duration(milliseconds: 2500);

/// Length of the static tint with reduced motion.
const settingsFocusReducedHold = Duration(milliseconds: 1500);

const _peakAlpha = 0.9;
const _troughAlpha = 0.55;

/// The targets of one Settings page, found by anchor. Held by the page's
/// scaffold and reached by the targets through [SettingsFocusScope].
class SettingsFocusRegistry {
  final Map<SettingsAnchor, SettingsFocusTargetState> _targets = {};

  /// The target of [anchor], or of its fallback when [anchor] is not built.
  SettingsFocusTargetState? find(SettingsAnchor anchor) {
    final target = _targets[anchor];
    if (target != null) return target;
    final fallback = anchor.fallback;
    return fallback == null ? null : find(fallback);
  }
}

/// Provides a [SettingsFocusRegistry] to the targets below it.
class SettingsFocusScope extends InheritedWidget {
  const SettingsFocusScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final SettingsFocusRegistry registry;

  @override
  bool updateShouldNotify(SettingsFocusScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Marks [child] as the place a link to [anchor] opens: the page scrolls to
/// it and it pulses in the container colour. Outside a
/// [SettingsFocusScope] it is just [child].
class SettingsFocusTarget extends StatefulWidget {
  const SettingsFocusTarget({
    super.key,
    required this.anchor,
    required this.child,
  });

  final SettingsAnchor anchor;
  final Widget child;

  @override
  State<SettingsFocusTarget> createState() => SettingsFocusTargetState();
}

class SettingsFocusTargetState extends State<SettingsFocusTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _alpha;
  SettingsFocusRegistry? _registry;
  Timer? _holdTimer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: settingsFocusPulseDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _running = false);
            }
          });
    // Fade in, one soft pulse, hold, fade out; weights are milliseconds.
    _alpha = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: _peakAlpha), weight: 300),
      TweenSequenceItem(
        tween: Tween(begin: _peakAlpha, end: _troughAlpha),
        weight: 450,
      ),
      TweenSequenceItem(
        tween: Tween(begin: _troughAlpha, end: _peakAlpha),
        weight: 450,
      ),
      TweenSequenceItem(tween: ConstantTween(_peakAlpha), weight: 500),
      TweenSequenceItem(tween: Tween(begin: _peakAlpha, end: 0.0), weight: 800),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = context
        .getInheritedWidgetOfExactType<SettingsFocusScope>()
        ?.registry;
    if (registry == _registry) return;
    _registry?._targets.remove(widget.anchor);
    _registry = registry?.._targets[widget.anchor] = this;
  }

  /// Starts the pulse, or restarts it from the beginning.
  void highlight() {
    if (!mounted) return;
    _holdTimer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      setState(() => _running = true);
      _holdTimer = Timer(settingsFocusReducedHold, () {
        if (mounted) setState(() => _running = false);
      });
    } else {
      setState(() => _running = true);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    final registry = _registry;
    if (registry != null && registry._targets[widget.anchor] == this) {
      registry._targets.remove(widget.anchor);
    }
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primaryContainer;
    final reduced = _holdTimer?.isActive ?? false;
    // A Material, not a coloured box: rows paint their ink on the nearest
    // Material, so hover and splash stay above the tint.
    return AnimatedBuilder(
      animation: _alpha,
      child: widget.child,
      builder: (context, child) => Material(
        type: _running ? MaterialType.canvas : MaterialType.transparency,
        color: _running
            ? tint.withValues(alpha: reduced ? _peakAlpha : _alpha.value)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
