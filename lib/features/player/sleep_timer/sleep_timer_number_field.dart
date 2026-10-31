import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Logical size of the big number.
const _fontSize = 60.0;

/// The big number of the sleep timer dialog, which can be typed over.
/// Digits only. Every edit reaches [onChanged] at once (a number over [max]
/// is shown as [max]); empty and zero leave [value] alone. Leaving the field
/// or pressing Enter shows [value] again, so the text never stays empty or
/// out of range; Enter then calls [onSubmit].
class SleepTimerNumberField extends StatefulWidget {
  const SleepTimerNumberField({
    super.key,
    required this.value,
    required this.max,
    required this.semanticsLabel,
    required this.onChanged,
    this.onSubmit,
    this.autofocus = false,
  });

  /// The last valid number.
  final int value;

  /// Largest number accepted; it sets how many digits can be typed.
  final int max;

  /// Screen reader name of the field.
  final String semanticsLabel;

  /// A typed number, kept apart from [value] until the parent rebuilds.
  final ValueChanged<int> onChanged;

  /// Enter was pressed (after the text was settled).
  final VoidCallback? onSubmit;

  final bool autofocus;

  @override
  State<SleepTimerNumberField> createState() => _SleepTimerNumberFieldState();
}

class _SleepTimerNumberFieldState extends State<SleepTimerNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChanged);

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SleepTimerNumberField old) {
    super.didUpdateWidget(old);
    // The number changed from outside (a button, the slider, a chip, another
    // tab): show it, unless the text already means it. Typing a number does
    // not rewrite the text, so the caret stays where it is.
    final rangeChanged = old.max != widget.max;
    if (rangeChanged ||
        (old.value != widget.value &&
            int.tryParse(_controller.text) != widget.value)) {
      _settle();
    }
  }

  void _settle() => _controller.text = '${widget.value}';

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      // Typing replaces the number.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _settle();
    }
    // Repaints the line under the number.
    setState(() {});
  }

  void _onEdited(String text) {
    final typed = int.tryParse(text);
    if (typed == null) return;
    if (typed > widget.max) {
      _controller.value = TextEditingValue(
        text: '${widget.max}',
        selection: TextSelection.collapsed(offset: '${widget.max}'.length),
      );
    }
    widget.onChanged(typed > widget.max ? widget.max : typed);
  }

  void _onSubmitted(String _) {
    _settle();
    widget.onSubmit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: widget.semanticsLabel,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _focus.hasFocus
              ? scheme.onSurface.withValues(alpha: 0.06)
              : null,
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: _focus.hasFocus ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter('${widget.max}'.length),
          ],
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
            color: scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration.collapsed(hintText: null),
          onChanged: _onEdited,
          onSubmitted: _onSubmitted,
        ),
      ),
    );
  }
}
