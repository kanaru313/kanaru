import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';
import 'app_destination.dart';

/// Visited locations and the position in them, like a browser history.
class NavigationHistoryState {
  const NavigationHistoryState(this.entries, this.index);

  final List<String> entries;
  final int index;

  bool get canGoBack => index > 0;
  bool get canGoForward => index < entries.length - 1;
}

/// Most locations kept; the oldest are dropped beyond it.
const navigationHistoryLimit = 100;

/// Records every location the router visits so the top bar's back and
/// forward buttons can move across pages. go_router only knows how to pop
/// within one stack, not how to go forward again.
class NavigationHistory extends Notifier<NavigationHistoryState> {
  @override
  NavigationHistoryState build() {
    final delegate = ref.watch(routerProvider).routerDelegate;
    void onRouteChanged() => _visit(_currentLocation());
    delegate.addListener(onRouteChanged);
    ref.onDispose(() => delegate.removeListener(onRouteChanged));
    return NavigationHistoryState([_currentLocation()], 0);
  }

  String _currentLocation() => ref
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  /// Index [back] or [forward] is moving to while the router has not reported
  /// where it landed yet.
  int? _pendingIndex;

  void _visit(String location) {
    final pending = _pendingIndex;
    if (pending != null) {
      // The router may have redirected; keep what it actually reached so the
      // forward stack is not mistaken for a new visit.
      _pendingIndex = null;
      _replaceAt(pending, location);
      return;
    }
    // Already there, e.g. because the router reported the same page twice.
    final current = state.entries[state.index];
    if (location == current) return;
    // Refining a search replaces the search entry, so one search session is
    // one history step; entries after it go, as with any new visit.
    final replacesSearch = _isSearch(current) && _isSearch(location);
    var entries = [
      ...state.entries.take(replacesSearch ? state.index : state.index + 1),
      location,
    ];
    if (entries.length > navigationHistoryLimit) {
      // A new list: the previous state's entries stay as they were.
      entries = entries.sublist(entries.length - navigationHistoryLimit);
    }
    state = NavigationHistoryState(entries, entries.length - 1);
  }

  static bool _isSearch(String location) =>
      Uri.parse(location).path == AppDestination.search.path;

  void _replaceAt(int index, String location) {
    if (state.entries[index] == location) return;
    final entries = [...state.entries]..[index] = location;
    state = NavigationHistoryState(entries, state.index);
  }

  void back() {
    if (state.canGoBack) _moveTo(state.index - 1);
  }

  void forward() {
    if (state.canGoForward) _moveTo(state.index + 1);
  }

  void _moveTo(int index) {
    final target = state.entries[index];
    state = NavigationHistoryState(state.entries, index);
    _pendingIndex = index;
    try {
      // Synchronous: the router reports where it landed before this returns.
      ref.read(routerProvider).go(target);
    } finally {
      // Going to where the router already is, or to a redirect that resolves
      // to it, notifies nobody; a pending index left behind would swallow the
      // next real visit.
      _pendingIndex = null;
    }
    _replaceAt(index, _currentLocation());
  }
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistory, NavigationHistoryState>(
      NavigationHistory.new,
    );
