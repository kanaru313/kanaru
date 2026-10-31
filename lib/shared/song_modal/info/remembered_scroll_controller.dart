import 'package:flutter/widgets.dart';

/// A scroll controller that starts at the offset its last scrollable had
/// when it was removed from the tree. The modal unmounts the page under the
/// one on top, so going back builds the list anew; this puts it where the
/// reader left it. It holds no resources until a scrollable attaches, so it
/// needs no dispose.
class RememberedScrollController extends ScrollController {
  double _offset = 0;

  @override
  double get initialScrollOffset => _offset;

  @override
  void detach(ScrollPosition position) {
    _offset = position.pixels;
    super.detach(position);
  }
}
