import 'package:material_ui/material_ui.dart';

/// The text box of one row of a list or map editor: its controller and focus
/// node, which [onBlur] hears when focus leaves the row.
class PluginConfigRowBox {
  PluginConfigRowBox(String text, {required VoidCallback onBlur})
    : controller = TextEditingController(text: text),
      focus = FocusNode() {
    focus.addListener(() {
      if (!focus.hasFocus) onBlur();
    });
  }

  final TextEditingController controller;
  final FocusNode focus;

  String get text => controller.text;

  void dispose() {
    focus.dispose();
    controller.dispose();
  }
}
