import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../router.dart';
import 'app_destination.dart';
import 'navigation_history.dart';

/// Pause after the last keystroke before the search page is opened.
const searchDebounce = Duration(milliseconds: 150);

/// Top bar search field. Typing opens `/search?q=…` after [searchDebounce],
/// Enter does so at once. The location stays the source of truth: the text
/// follows `q` when the user navigates back, forward or elsewhere.
class TopBarSearchField extends ConsumerStatefulWidget {
  const TopBarSearchField({super.key});

  @override
  ConsumerState<TopBarSearchField> createState() => _TopBarSearchFieldState();
}

class _TopBarSearchFieldState extends ConsumerState<TopBarSearchField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  Timer? _debounce;

  /// Last `q` this field navigated to, so the route echo of it does not
  /// overwrite text typed since.
  String? _sentQuery;

  @override
  void initState() {
    super.initState();
    final uri = ref
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri;
    final text = uri.path == AppDestination.search.path
        ? uri.queryParameters['q'] ?? ''
        : '';
    _controller = TextEditingController(text: text);
    if (uri.path == AppDestination.search.path) _sentQuery = text;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _go(String text) {
    _debounce?.cancel();
    final query = text.trim();
    _sentQuery = query;
    // Opening the page moves focus into its route; give it back to a field
    // the user is still typing in.
    final hadFocus = _focusNode.hasFocus;
    context.go(
      Uri(
        path: AppDestination.search.path,
        queryParameters: query.isEmpty ? null : {'q': query},
      ).toString(),
    );
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _onLocationChanged(String location) {
    final uri = Uri.parse(location);
    if (uri.path != AppDestination.search.path) {
      _debounce?.cancel();
      _sentQuery = null;
      _controller.clear();
      return;
    }
    final query = uri.queryParameters['q'] ?? '';
    if (query == _sentQuery) return;
    _sentQuery = query;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navigationHistoryProvider, (_, history) {
      _onLocationChanged(history.entries[history.index]);
    });
    return SearchBar(
      controller: _controller,
      focusNode: _focusNode,
      hintText: context.l10n.topBarSearchHint,
      leading: const Icon(Icons.search, size: 20),
      elevation: const WidgetStatePropertyAll(0),
      constraints: const BoxConstraints(minHeight: 40),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      onChanged: (text) {
        _debounce?.cancel();
        _debounce = Timer(searchDebounce, () => _go(text));
      },
      onSubmitted: _go,
    );
  }
}
