import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// One piece of a [HoverUnderlineLinks] line: a link when [onTap] is set,
/// plain text otherwise.
class LinkSegment {
  const LinkSegment(this.text, {this.onTap});

  final String text;

  /// Called with the global position of the tap (or the line's bottom-left
  /// for keyboard and semantic activation). Null makes the segment plain.
  final ValueChanged<Offset>? onTap;
}

/// A one-line run of text links and plain text. A link looks like its
/// neighbours until the mouse is over it, then only that link is underlined.
/// Keyboard focus (one Tab stop for the whole line) underlines every link.
/// Plain segments (separators) are never underlined and never tappable.
///
/// The hit area is the glyphs only, and the line keeps `maxLines: 1` with an
/// ellipsis.
class HoverUnderlineLinks extends StatefulWidget {
  const HoverUnderlineLinks({super.key, required this.segments, this.style});

  final List<LinkSegment> segments;
  final TextStyle? style;

  @override
  State<HoverUnderlineLinks> createState() => _HoverUnderlineLinksState();
}

class _HoverUnderlineLinksState extends State<HoverUnderlineLinks> {
  // Recognizers live in the state, never in build: TextSpan equality compares
  // them, so fresh ones every build would make every span look changed.
  final List<TapGestureRecognizer?> _recognizers = [];
  final List<void Function(PointerEnterEvent)> _enters = [];
  final List<void Function(PointerExitEvent)> _exits = [];

  int? _hoveredIndex;
  bool _focused = false;

  // Callback and position captured at pointer down, so a segment list swapped
  // before pointer up still runs what the user pressed.
  ValueChanged<Offset>? _pressedCallback;
  Offset? _pressedPosition;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(HoverUnderlineLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRecognizers();
    final hovered = _hoveredIndex;
    if (hovered != null && !_isLink(hovered)) _hoveredIndex = null;
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer?.dispose();
    }
    super.dispose();
  }

  bool _isLink(int i) =>
      i < widget.segments.length && widget.segments[i].onTap != null;

  /// Keeps one recognizer (and enter/exit pair) per segment index, present
  /// only for link segments.
  void _syncRecognizers() {
    final count = widget.segments.length;
    while (_recognizers.length > count) {
      _disposeRecognizerAt(_recognizers.length - 1);
      _recognizers.removeLast();
      _enters.removeLast();
      _exits.removeLast();
    }
    while (_recognizers.length < count) {
      final i = _recognizers.length;
      _recognizers.add(null);
      _enters.add((_) => _setHovered(i, true));
      _exits.add((_) => _setHovered(i, false));
    }
    for (var i = 0; i < count; i++) {
      if (_isLink(i)) {
        _recognizers[i] ??= _newRecognizer(i);
      } else {
        _disposeRecognizerAt(i);
        _recognizers[i] = null;
      }
    }
  }

  /// Disposing a recognizer cancels its gesture without `onTapCancel`, so the
  /// press captured for that segment must be dropped here or a later semantic
  /// tap would run a stale callback.
  void _disposeRecognizerAt(int i) {
    _recognizers[i]?.dispose();
    if (_pressedIndex == i) {
      _pressedCallback = null;
      _pressedPosition = null;
      _pressedIndex = null;
    }
  }

  // `onTap` must be set even though `onTapDown` carries the work: only a
  // recognizer with `onTap` makes the paragraph expose a semantic tap action
  // and the link flag.
  TapGestureRecognizer _newRecognizer(int i) => TapGestureRecognizer()
    ..onTapDown = (details) {
      _pressedIndex = i;
      _pressedPosition = details.globalPosition;
      _pressedCallback = i < widget.segments.length
          ? widget.segments[i].onTap
          : null;
    }
    ..onTap = () {
      // Without a preceding tap-down this is a semantic tap.
      final callback =
          _pressedCallback ??
          (i < widget.segments.length ? widget.segments[i].onTap : null);
      final position = _pressedPosition ?? _lineBottomLeft();
      _pressedCallback = null;
      _pressedPosition = null;
      _pressedIndex = null;
      callback?.call(position);
    }
    ..onTapCancel = () {
      _pressedCallback = null;
      _pressedPosition = null;
      _pressedIndex = null;
    };

  Offset _lineBottomLeft() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.bottomLeft(Offset.zero));
  }

  // `onExit` of a span still fires after the State is disposed (for example a
  // tap navigates away while the pointer is over the link), hence `mounted`.
  void _setHovered(int i, bool hovered) {
    if (!mounted) return;
    final next = hovered ? i : (_hoveredIndex == i ? null : _hoveredIndex);
    if (next == _hoveredIndex) return;
    setState(() => _hoveredIndex = next);
  }

  void _setFocused(bool focused) {
    if (!mounted || focused == _focused) return;
    setState(() => _focused = focused);
  }

  void _activate() {
    for (final segment in widget.segments) {
      final onTap = segment.onTap;
      if (onTap != null) {
        onTap(_lineBottomLeft());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <InlineSpan>[];
    for (var i = 0; i < widget.segments.length; i++) {
      final segment = widget.segments[i];
      if (segment.onTap == null) {
        children.add(TextSpan(text: segment.text));
        continue;
      }
      final underline = _focused || _hoveredIndex == i;
      children.add(
        TextSpan(
          text: segment.text,
          style: TextStyle(
            // Null keeps any decoration inherited from the line's style.
            decoration: underline ? TextDecoration.underline : null,
          ),
          recognizer: _recognizers[i],
          onEnter: _enters[i],
          onExit: _exits[i],
        ),
      );
    }
    final text = Text.rich(
      TextSpan(children: children),
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!widget.segments.any((s) => s.onTap != null)) return text;
    return FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onShowFocusHighlight: _setFocused,
      child: text,
    );
  }
}
