import 'package:flutter/widgets.dart';

/// One filter box on a page that `Ctrl+F` can open.
class InPageFilterHandle {
  const InPageFilterHandle({
    required this.context,
    required this.open,
    required this.hasFocus,
    this.layer = 0,
    this.isAvailable = _always,
  });

  static bool _always() => true;

  /// Context of the page that owns the box; must be the owning state's
  /// context so [BuildContext.mounted] tells when the page is gone. It must
  /// belong to a widget that is actually shown while the box can be opened:
  /// visibility is read from this context's route and ticker mode.
  final BuildContext context;

  /// Shows the box and focuses it.
  final VoidCallback open;

  /// Whether the box has keyboard focus right now.
  final bool Function() hasFocus;

  /// Boxes on a higher layer win over lower ones that are visible too (an
  /// overlay above a page). Equal layers: the latest registration wins.
  final int layer;

  /// Whether the page has a box to open right now. A page with nothing to
  /// filter (an empty playlist) says false, so `Ctrl+F` falls through to the
  /// library-wide search instead of opening a box nobody can see.
  final bool Function() isAvailable;
}

/// Filter boxes of the pages that are built right now. The top bar's `Ctrl+F`
/// asks it for the box of the page the user is looking at before it falls
/// back to the library-wide search field.
class InPageFilterRegistry {
  InPageFilterRegistry._();

  static final instance = InPageFilterRegistry._();

  /// Oldest first.
  final _handles = <InPageFilterHandle>[];

  void register(InPageFilterHandle handle) {
    _handles
      ..remove(handle)
      ..add(handle);
  }

  void unregister(InPageFilterHandle handle) => _handles.remove(handle);

  /// Handles whose page is mounted, on the current route and not in a hidden
  /// shell branch, newest first.
  Iterable<InPageFilterHandle> get _visible sync* {
    for (final handle in _handles.reversed) {
      final context = handle.context;
      if (!context.mounted || !_isActive(context)) continue;
      if (!handle.isAvailable()) continue;
      // `ModalRoute.of` has no public non-depending twin; the extra
      // dependency only rebuilds the page on route changes.
      if (ModalRoute.of(context)?.isCurrent == false) continue;
      if (!TickerMode.getValuesNotifier(context).value.enabled) continue;
      yield handle;
    }
  }

  /// A deactivated element is still mounted but must not be looked up from.
  /// The check exists in debug builds only, where the lookups assert.
  static bool _isActive(BuildContext context) {
    var active = true;
    assert(() {
      if (context is Element) active = context.debugIsActive;
      return true;
    }());
    return active;
  }

  /// Whether the keyboard focus is in the box of a visible page.
  bool get hasFocus => _visible.any((handle) => handle.hasFocus());

  /// Opens the visible box on the highest layer, the latest registered among
  /// equals. False when no page has one.
  bool openTop() {
    InPageFilterHandle? top;
    for (final handle in _visible) {
      if (top == null || handle.layer > top.layer) top = handle;
    }
    if (top == null) return false;
    top.open();
    return true;
  }
}
