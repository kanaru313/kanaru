import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_fields.dart';
import 'search_prefs.dart';
import 'search_prefs_file.dart';

export 'search_prefs.dart';
export 'search_prefs_file.dart' show SearchPrefsFile, searchPrefsFileFor;

/// Where the search prefs are saved. `null` (the default, used by tests)
/// keeps them in memory only; `main()` overrides it.
final searchPrefsFileProvider = Provider<SearchPrefsFile?>((ref) => null);

/// Search history and chosen fields. Loads the file asynchronously, so the
/// first frame does not wait for it; every change is saved right away.
class SearchPrefsNotifier extends AsyncNotifier<SearchPrefs> {
  @override
  Future<SearchPrefs> build() async =>
      await ref.read(searchPrefsFileProvider)?.load() ?? const SearchPrefs();

  Future<void> record(String raw) => _change((p) => p.record(raw));

  Future<void> remove(String entry) => _change((p) => p.remove(entry));

  Future<void> clear() => _change((p) => p.clear());

  Future<void> setFields(Set<SearchField> fields) =>
      _change((p) => p.withFields(fields));

  /// Waits for the stored prefs first, so an early change does not replace
  /// them with defaults, then applies [change] to the latest state.
  Future<void> _change(SearchPrefs Function(SearchPrefs) change) async {
    final current = await future;
    final next = change(state.value ?? current);
    if (identical(next, state.value)) return;
    state = AsyncData(next);
    await ref.read(searchPrefsFileProvider)?.save(next);
  }
}

final searchPrefsProvider =
    AsyncNotifierProvider<SearchPrefsNotifier, SearchPrefs>(
      SearchPrefsNotifier.new,
    );
