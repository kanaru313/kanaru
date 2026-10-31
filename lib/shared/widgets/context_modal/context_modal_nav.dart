import 'dart:ui' show VoidCallback;

import 'context_modal_page.dart';

/// What a modal's callbacks can do to the modal. Handed to every action and
/// page builder so they never hold a row's own `BuildContext`.
class ContextModalNav {
  const ContextModalNav({
    required this.push,
    required this.pop,
    required this.close,
  });

  /// Opens [page] on top of the current one.
  final void Function(ContextModalPage page) push;

  /// Goes back one page; closes the modal when already on the first page.
  final VoidCallback pop;

  /// Closes the modal, completing `showContextModal` with [result].
  final void Function([Object? result]) close;
}
