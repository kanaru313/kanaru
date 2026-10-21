import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/search_terms.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_keys_updating.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'search_providers.dart';
import 'search_results_view.dart';

final _log = Logger('library.search');

/// The results the page last had, kept while the next query loads.
class _Shown {
  const _Shown(this.termsKey, this.query, this.results);

  final String termsKey;
  final String query;
  final SearchResults results;
}

/// Songs, albums and artists matching [query]: the text submitted from the
/// top bar. Without a library, folders or finished keys it says so like the
/// library pages do.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.query = ''});

  final String query;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  _Shown? _shown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final terms = searchTerms(widget.query);
    if (terms.isEmpty) {
      return PageScaffold(
        title: l10n.navSearch,
        body: EmptyState(
          icon: Icons.search,
          title: l10n.searchEmptyTitle,
          message: l10n.searchEmptyMessage,
        ),
      );
    }
    final termsKey = terms.join(' ');
    return PageScaffold(
      title: l10n.searchResultsTitle(widget.query),
      body: _body(context, termsKey),
    );
  }

  Widget _body(BuildContext context, String termsKey) {
    final l10n = context.l10n;
    if (ref.watch(libraryDatabaseProvider) == null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      );
    }
    if (!ref.watch(libraryHasRootsProvider)) {
      return EmptyState(
        icon: Icons.music_note_outlined,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
      );
    }
    if (ref.watch(keysUpdatingProvider)) return const LibraryKeysUpdating();
    if (!ref.watch(keysReadyProvider)) return const LibraryLoading();

    ref.listen(searchResultsProvider(termsKey), (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Searching the library failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final async = ref.watch(searchResultsProvider(termsKey));
    final fresh = async.value;
    if (fresh != null) _shown = _Shown(termsKey, widget.query, fresh);
    final shown = _shown;
    if (shown == null) {
      return async.hasError
          ? EmptyState(
              icon: Icons.error_outline,
              title: l10n.libraryUnavailableTitle,
              message: l10n.libraryUnexpectedError,
            )
          : const LibraryLoading();
    }
    if (shown.results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.searchNoResultsTitle,
        message: l10n.searchNoResultsMessage(shown.query),
      );
    }
    return SearchResultsView(
      key: ValueKey(shown.termsKey),
      results: shown.results,
    );
  }
}
