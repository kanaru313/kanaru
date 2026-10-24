import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/database/search_terms.dart';
import '../core/search/in_page_match.dart';

/// Longest wait after a key press before the filter terms follow the text.
const inPageFilterDebounce = Duration(milliseconds: 100);

/// State of one filter box: whether it is shown, its text and the search
/// terms of that text (updated [inPageFilterDebounce] after the last key).
/// Listeners are told when the box opens or closes and when the terms
/// change. The page that owns it creates and disposes it, so leaving the page
/// drops the filter.
class InPageFilterController extends ChangeNotifier {
  InPageFilterController({this.debounce = inPageFilterDebounce}) {
    text.addListener(_onText);
    focus.addListener(_onFocus);
  }

  final Duration debounce;

  /// The text field's controller and focus, handed to the field.
  final text = TextEditingController();
  final focus = FocusNode(debugLabel: 'in-page filter');

  bool _open = false;
  bool _disposed = false;
  String _seenText = '';
  String _query = '';
  List<String> _terms = const [];
  Timer? _timer;

  bool get isOpen => _open;

  /// Terms of the text as of the last update; empty when nothing filters.
  List<String> get terms => _terms;

  /// The trimmed text the [terms] come from, for messages.
  String get query => _query;

  bool get isFiltering => _terms.isNotEmpty;

  /// Shows the box, focuses it and selects its text.
  void open() {
    if (_disposed) return;
    if (_open) {
      _focusAndSelect();
      return;
    }
    _open = true;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_open && !_disposed) _focusAndSelect();
    });
  }

  /// Empties the text and hides the box; the filter is gone at once.
  void close() {
    if (_disposed || !_open) return;
    _open = false;
    _timer?.cancel();
    _seenText = '';
    text.clear();
    _update();
    notifyListeners();
  }

  /// Empties the text, keeping the box open and focused.
  void clear() {
    _timer?.cancel();
    _seenText = '';
    text.clear();
    if (_update()) notifyListeners();
    focus.requestFocus();
  }

  void _focusAndSelect() {
    focus.requestFocus();
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
  }

  void _onText() {
    if (text.text == _seenText) return;
    _seenText = text.text;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (_update()) notifyListeners();
    });
  }

  /// An empty box that lost focus has nothing left to show. Checked after
  /// the frame: a page being torn down also drops focus.
  void _onFocus() {
    if (focus.hasFocus || !_open || text.text.isNotEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && _open && !focus.hasFocus && text.text.isEmpty) close();
    });
  }

  /// Takes the terms of the current text; whether they changed.
  bool _update() {
    final terms = searchTerms(text.text);
    final query = text.text.trim();
    final changed = !listEquals(terms, _terms) || query != _query;
    _terms = terms;
    _query = query;
    return changed;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    focus.dispose();
    text.dispose();
    super.dispose();
  }
}

/// Ranks the songs of a page for the terms of a filter box. The words of the
/// list are folded once and kept until the list itself is replaced, so a key
/// press does not fold them again.
class InPageFilterView<T> {
  InPageFilterView(this._entryOf);

  final InPageEntry Function(T item) _entryOf;
  List<T>? _source;
  InPageIndex? _index;

  /// Positions in [items] of the matches of [terms], best first; every
  /// position, in order, without terms.
  List<int> rank(List<T> items, List<String> terms) => [
    for (final tier in tiers(items, terms)) ...tier,
  ];

  /// The matches of [terms] split by tier, best tier first (see
  /// [InPageIndex.tiers]); the one tier of every position without terms.
  List<List<int>> tiers(List<T> items, List<String> terms) {
    if (terms.isEmpty) {
      return [
        [for (var i = 0; i < items.length; i++) i],
      ];
    }
    if (!identical(items, _source)) {
      _index = InPageIndex([for (final item in items) _entryOf(item)]);
      _source = items;
    }
    return _index!.tiers(terms);
  }

  /// [items] themselves without terms, else the matches, best first.
  List<T> apply(List<T> items, List<String> terms) =>
      terms.isEmpty ? items : [for (final i in rank(items, terms)) items[i]];
}
