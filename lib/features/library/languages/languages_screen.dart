import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';
import '../library_view_modes.dart';
import '../widgets/page_material.dart';
import 'enqueue_language.dart';
import 'language_grid_tile.dart';
import 'language_tile.dart';
import 'languages_provider.dart';

final _log = Logger('library');

/// Row used to measure the list.
const _prototypeLanguage = LanguageSummary(
  key: 'prototype',
  name: 'Language',
  songCount: 1,
  raws: [],
);

/// Every language named by a language tag, by key, as a list or a grid of
/// round tiles. Tapping one opens its page.
class LanguagesScreen extends ConsumerWidget {
  const LanguagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(languagesProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading the languages failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final view = ref.watch(libraryViewModesProvider.select((m) => m.languages));
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    void open(LanguageSummary language) =>
        context.go(languageLocation(language.key));
    void enqueue(LanguageSummary language, QueueAction action) =>
        enqueueLanguage(ref, context, action, language);

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navLanguages,
        actions: [
          if (showActions)
            // Shows the current view; a tap switches to the other one.
            IconButton(
              tooltip: switch (view) {
                AlbumsView.grid => l10n.albumsGridView,
                AlbumsView.list => l10n.albumsListView,
              },
              icon: Icon(switch (view) {
                AlbumsView.grid => AppIcons.viewGrid,
                AlbumsView.list => AppIcons.viewList,
              }),
              onPressed: () => ref
                  .read(libraryViewModesProvider.notifier)
                  .setLanguagesView(switch (view) {
                    AlbumsView.grid => AlbumsView.list,
                    AlbumsView.list => AlbumsView.grid,
                  }),
            ),
        ],
        body: LibraryBrowseBody<LanguageSummary>(
          hasError: ref.watch(languagesProvider.select((s) => s.hasError)),
          items: ref.watch(languagesProvider).value,
          icon: AppIcons.language,
          noRootsMessage: l10n.languagesNoRootsMessage,
          emptyTitle: l10n.languagesEmptyTitle,
          emptyMessage: l10n.languagesEmptyMessage,
          builder: (languages) => switch (view) {
            AlbumsView.grid => LanguageGrid(
              languages: languages,
              onTap: open,
              onQueueAction: enqueue,
            ),
            AlbumsView.list => ListView.builder(
              padding: libraryListBottomPadding,
              prototypeItem: LanguageTile(
                language: _prototypeLanguage,
                onTap: () {},
              ),
              itemCount: languages.length,
              itemBuilder: (context, i) => LanguageTile(
                language: languages[i],
                onTap: () => open(languages[i]),
                onQueueAction: (action) => enqueue(languages[i], action),
              ),
            ),
          },
        ),
      ),
    );
  }
}
