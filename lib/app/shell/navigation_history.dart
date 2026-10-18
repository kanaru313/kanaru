import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';

/// Visited locations and the position in them, like a browser history.
class NavigationHistoryState {
  const NavigationHistoryState(this.entries, this.index);

  final List<String> entries;
  final int index;

  bool get canGoBack => index > 0;
  bool get canGoForward => index < entries.length - 1;
}

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

  void _visit(String location) {
    // Already there, e.g. because back() or forward() just moved the index.
    if (location == state.entries[state.index]) return;
    final entries = [...state.entries.take(state.index + 1), location];
    state = NavigationHistoryState(entries, entries.length - 1);
  }

  void back() {
    if (state.canGoBack) _moveTo(state.index - 1);
  }

  void forward() {
    if (state.canGoForward) _moveTo(state.index + 1);
  }

  void _moveTo(int index) {
    state = NavigationHistoryState(state.entries, index);
    ref.read(routerProvider).go(state.entries[index]);
  }
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistory, NavigationHistoryState>(
      NavigationHistory.new,
    );
