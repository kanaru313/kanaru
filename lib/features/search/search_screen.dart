import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../core/search/search_prefs_provider.dart';
import '../../core/search/search_query.dart';
import '../../core/search/search_query_parser.dart';
import '../../core/search/typo_correction.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_keys_updating.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'search_field_picker.dart';
import 'search_providers.dart';
import 'search_query_display.dart';
import 'search_request_provider.dart';
import 'search_results_view.dart';
import 'search_typo_providers.dart';

final _log = Logger('library.search');

/// The results the page last had, kept while the next query loads.
class _Shown {
  const _Shown(this.requestKey, this.query, this.results, this.narrowFields);

  final String requestKey;
  final String query;
  final SearchResults results;

  /// Whether the fields behind these results were narrowed and the query had
  /// free words (the only part the picker affects).
  final bool narrowFields;
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
    // Keep the name indexes loaded while the page is mounted, so the first
    // search after clearing the field does not load the library again.
    ref.listen(searchAlbumIndexProvider, (_, _) {});
    ref.listen(searchArtistIndexProvider, (_, _) {});
    // The dictionary of a typo-tolerant retry stays loaded while the page
    // keeps finding few songs, so typing on does not read it again.
    if (_shown?.results.needsVocabulary ?? false) {
      ref.listen(searchVocabularyProvider, (_, _) {});
    }
    final parsed = parseSearchQuery(widget.query);
    // Shown even without a query, to choose before typing.
    const actions = [SearchFieldPicker()];
    if (parsed.isEmpty) {
      return PageScaffold(
        title: l10n.navSearch,
        actions: actions,
        body: EmptyState(
          icon: AppIcons.search,
          title: l10n.searchEmptyTitle,
          message: l10n.searchEmptyMessage,
        ),
      );
    }
    final fields = ref.watch(searchFieldsProvider);
    final request = SearchRequest(query: parsed, fields: fields);
    return PageScaffold(
      title: l10n.searchResultsTitle(displaySearchQueryText(l10n, widget.query)),
      actions: actions,
      body: _body(context, request),
    );
  }

  /// Remembers the query as typed (syntax included) once a result is opened.
  void _remember() =>
      unawaited(ref.read(searchPrefsProvider.notifier).record(widget.query));

  Widget _body(BuildContext context, SearchRequest request) {
    final l10n = context.l10n;
    if (ref.watch(libraryDatabaseProvider) == null) {
      return EmptyState(
        icon: AppIcons.errorOutline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      );
    }
    if (!ref.watch(libraryHasRootsProvider)) {
      return EmptyState(
        icon: AppIcons.musicNoteOutlined,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
      );
    }
    if (ref.watch(keysUpdatingProvider)) return const LibraryKeysUpdating();
    if (!ref.watch(keysReadyProvider)) return const LibraryLoading();

    ref.listen(searchResultsProvider(request), (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Searching the library failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final async = ref.watch(searchResultsProvider(request));
    final fresh = async.value;
    if (fresh != null) {
      _shown = _Shown(
        request.key,
        widget.query,
        fresh,
        request.query.freeTerms.isNotEmpty &&
            !isDefaultSearchFields(request.fields),
      );
    }
    // The previous query's results stand in only while this one loads; a
    // failure of this query is shown as such.
    if (fresh == null && async.hasError) {
      return EmptyState(
        icon: AppIcons.errorOutline,
        title: l10n.searchFailedTitle,
        message: l10n.libraryUnexpectedError,
      );
    }
    final shown = _shown;
    if (shown == null) return const LibraryLoading();
    if (shown.results.isEmpty) {
      // A song may still be on its way while the first scan runs.
      if (ref.watch(
        libraryIndexerProvider.select((s) => s is IndexerScanning),
      )) {
        return const LibraryLoading();
      }
      return EmptyState(
        icon: AppIcons.searchOff,
        title: l10n.searchNoResultsTitle,
        message: shown.narrowFields
            ? l10n.searchNoResultsNarrowFields(
                displaySearchQueryText(l10n, shown.query),
              )
            : l10n.searchNoResultsMessage(
                displaySearchQueryText(l10n, shown.query),
              ),
      );
    }
    return SearchResultsView(
      key: ValueKey(shown.requestKey),
      results: shown.results,
      correctedQuery: shown.results.corrections.isEmpty
          ? null
          : correctedQueryText(shown.query, shown.results.corrections),
      onOpened: _remember,
    );
  }
}
