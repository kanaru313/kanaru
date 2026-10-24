import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/search/search_prefs_provider.dart';
import '../../features/player/now_playing/now_playing_open_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../router.dart';
import 'app_destination.dart';
import 'navigation_history.dart';
import 'search_query_highlighting_controller.dart';
import 'top_bar_search_history_host.dart';
import 'top_bar_search_shortcuts.dart';

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

  late final TopBarSearchShortcuts _shortcuts;

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
    _controller = SearchQueryHighlightingController(text: text);
    if (uri.path == AppDestination.search.path) _sentQuery = text;
    _shortcuts = TopBarSearchShortcuts(
      focusNode: _focusNode,
      controller: _controller,
      isNowPlayingOpen: () => ref.read(nowPlayingOpenProvider),
    )..attach();
  }

  @override
  void dispose() {
    _shortcuts.detach();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Fills the field with a history entry and searches for it at once.
  void _pick(String entry) {
    _controller.value = TextEditingValue(
      text: entry,
      selection: TextSelection.collapsed(offset: entry.length),
    );
    ref.read(searchPrefsProvider.notifier).record(entry);
    _go(entry);
  }

  void _submit(String text) {
    if (text.trim().isNotEmpty) {
      ref.read(searchPrefsProvider.notifier).record(text);
    }
    _go(text);
  }

  void _go(String text) {
    _debounce?.cancel();
    final query = text.trim();
    _sentQuery = query;
    // Navigation takes focus only when the search page section is first
    // built (not on later query changes). The refocus runs in the same
    // frame, so focus is never visibly lost and the IME connection stays
    // open while the user keeps typing.
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
    // The route changed under the field (Back, Forward, a link): text typed
    // for the old location must not fire afterwards.
    _debounce?.cancel();
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
    return TopBarSearchHistoryHost(
      controller: _controller,
      focusNode: _focusNode,
      onPick: _pick,
      child: _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    return SearchBar(
      controller: _controller,
      focusNode: _focusNode,
      hintText: context.l10n.topBarSearchHint,
      leading: const Icon(AppIcons.search, size: 20),
      elevation: const WidgetStatePropertyAll(0),
      constraints: const BoxConstraints(minHeight: 40),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      onChanged: (text) {
        _debounce?.cancel();
        // Off the search page, blank text would only add an empty search
        // entry to the history.
        if (_sentQuery == null && text.trim().isEmpty) return;
        _debounce = Timer(searchDebounce, () => _go(text));
      },
      onSubmitted: _submit,
    );
  }
}
