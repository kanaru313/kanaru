import 'package:flutter/widgets.dart';

import 'in_page_filter.dart';
import 'in_page_filter_registry.dart';

/// For the [State] of a page that owns an [InPageFilterController]: registers
/// the page with [InPageFilterRegistry] for as long as the page lives, so
/// `Ctrl+F` reaches the page whichever widget has the focus. Dispose of the
/// controller yourself, before calling `super.dispose()`.
mixin InPageFilterHost<T extends StatefulWidget> on State<T> {
  /// The filter of this page.
  InPageFilterController get filterController;

  /// Higher layers win over lower ones (an overlay above a page).
  int get filterLayer => 0;

  /// Whether the page has anything to filter right now; false keeps `Ctrl+F`
  /// from opening a box that is not shown.
  bool get filterAvailable => true;

  late final InPageFilterHandle _filterHandle;

  @override
  void initState() {
    super.initState();
    _filterHandle = InPageFilterHandle(
      context: context,
      open: filterController.open,
      hasFocus: () => filterController.focus.hasFocus,
      layer: filterLayer,
      isAvailable: () => filterAvailable,
    );
    InPageFilterRegistry.instance.register(_filterHandle);
  }

  @override
  void dispose() {
    InPageFilterRegistry.instance.unregister(_filterHandle);
    super.dispose();
  }
}
