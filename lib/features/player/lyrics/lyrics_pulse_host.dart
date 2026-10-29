import 'package:material_ui/material_ui.dart';

/// One step of the placeholder pulse.
const _pulseDuration = Duration(milliseconds: 900);

/// Owns the one controller that pulses every placeholder bar of a lyrics
/// view (a translation on its way, an online search). It runs only while
/// [active] and motion is allowed; the animation handed to [builder] is
/// `null` otherwise, which keeps the bars still.
class LyricsPulseHost extends StatefulWidget {
  const LyricsPulseHost({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final Widget Function(BuildContext context, Animation<double>? pulse) builder;

  @override
  State<LyricsPulseHost> createState() => _LyricsPulseHostState();
}

class _LyricsPulseHostState extends State<LyricsPulseHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 1,
  ).animate(_curve);

  bool get _pulsing =>
      widget.active && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_pulsing) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LyricsPulseHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _pulsing ? _opacity : null);
}
