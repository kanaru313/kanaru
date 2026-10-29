import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../in_page_filter.dart';

/// Widest the open filter box gets.
const inPageSearchWidth = 280.0;

/// The text box of a filter: a compact field with a clear button. Esc empties
/// it and closes it; [onEscape] then gets the focus back to where the box
/// was opened from.
class InPageSearchBox extends StatelessWidget {
  const InPageSearchBox({
    super.key,
    required this.controller,
    this.onEscape,
    this.width = inPageSearchWidth,
    this.hintText,
  });

  final InPageFilterController controller;
  final VoidCallback? onEscape;

  /// Width of the box; `double.infinity` fills the row it sits in.
  final double width;

  /// Placeholder of the empty box; the generic filter hint when null.
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        controller.close();
        onEscape?.call();
        return KeyEventResult.handled;
      },
      child: SizedBox(
        width: width,
        child: TextField(
          controller: controller.text,
          focusNode: controller.focus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText ?? l10n.inPageSearchHint,
            prefixIcon: const Icon(AppIcons.search, size: 20),
            suffixIcon: ValueListenableBuilder(
              valueListenable: controller.text,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(AppIcons.close, size: 18),
                      tooltip: l10n.inPageSearchClear,
                      onPressed: controller.clear,
                    ),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

/// The filter of a page: a search button that turns into a [InPageSearchBox]
/// when pressed. `Ctrl+F` is wired by the page that owns the controller (see
/// `InPageFilterHost`), not here.
class InPageSearchField extends StatefulWidget {
  const InPageSearchField({
    super.key,
    required this.controller,
    this.hintText,
    this.width = inPageSearchWidth,
  });

  final InPageFilterController controller;

  /// Placeholder of the open box; the generic filter hint when null.
  final String? hintText;

  /// Width of the open box.
  final double width;

  @override
  State<InPageSearchField> createState() => _InPageSearchFieldState();
}

class _InPageSearchFieldState extends State<InPageSearchField> {
  final _iconFocus = FocusNode(debugLabel: 'in-page filter button');

  @override
  void dispose() {
    _iconFocus.dispose();
    super.dispose();
  }

  void _focusButton() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _iconFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.isOpen
          ? InPageSearchBox(
              controller: controller,
              onEscape: _focusButton,
              width: widget.width,
              hintText: widget.hintText,
            )
          // Joins the text-field tap region so a click here does not count as
          // a tap outside a focused field.
          : TextFieldTapRegion(
              child: IconButton(
                focusNode: _iconFocus,
                icon: const Icon(AppIcons.search),
                tooltip: context.l10n.inPageSearchOpen,
                onPressed: controller.open,
              ),
            ),
    );
  }
}
