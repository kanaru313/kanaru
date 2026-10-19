import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/indexer_providers.dart';
import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import 'songs/songs_empty_view.dart';
import 'widgets/library_loading.dart';

/// The states shared by the Albums and Artists screens: library unavailable,
/// no music folder yet (only a hint: adding folders happens in Songs),
/// loading, nothing found, or the [toolbar] above the [builder] content.
class LibraryBrowseBody<T> extends ConsumerWidget {
  const LibraryBrowseBody({
    super.key,
    required this.state,
    required this.items,
    required this.icon,
    required this.noRootsMessage,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.toolbar,
    required this.builder,
  });

  /// The load state of the list (loading, failed).
  final AsyncValue<Object?> state;

  /// The latest list, sorted; null until one loaded. Kept when a later
  /// reload fails (the screen logs the error).
  final List<T>? items;
  final IconData icon;
  final String noRootsMessage;
  final String emptyTitle;
  final String emptyMessage;
  final Widget toolbar;
  final Widget Function(List<T> items) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (ref.watch(libraryDatabaseProvider) == null) {
      return const SongsEmptyView(kind: SongsEmptyKind.unavailable);
    }
    if (!ref.watch(libraryHasRootsProvider)) {
      return EmptyState(
        icon: icon,
        title: l10n.libraryEmptyTitle,
        message: noRootsMessage,
      );
    }
    final scanning = ref.watch(
      libraryIndexerProvider.select((s) => s is IndexerScanning),
    );

    final list = items;
    if (list == null) {
      return state.hasError
          ? const SongsEmptyView(kind: SongsEmptyKind.unavailable)
          : const LibraryLoading();
    }
    if (list.isEmpty) {
      return scanning
          ? const SizedBox.shrink()
          : EmptyState(icon: icon, title: emptyTitle, message: emptyMessage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: toolbar,
        ),
        Expanded(child: builder(list)),
      ],
    );
  }
}
