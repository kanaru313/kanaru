import 'package:flutter/widgets.dart';

/// Which frame the modal currently sits in, for widgets inside it that lay
/// out differently in a narrow bottom sheet (the chips).
class ContextModalFrameScope extends InheritedWidget {
  const ContextModalFrameScope({
    super.key,
    required this.isSheet,
    required super.child,
  });

  final bool isSheet;

  /// False outside a modal.
  static bool isSheetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ContextModalFrameScope>()
          ?.isSheet ??
      false;

  @override
  bool updateShouldNotify(ContextModalFrameScope old) => isSheet != old.isSheet;
}
