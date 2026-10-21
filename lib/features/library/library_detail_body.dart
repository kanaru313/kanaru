import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import 'songs/songs_empty_view.dart';
import 'widgets/library_loading.dart';
import 'widgets/page_material.dart';

final _log = Logger('library');

/// Body of the album and artist pages: library unavailable, loading, a
/// failed read (logged; once a page was shown it stays), "not found" (a
/// broken key, given as a null [page], or a page value of null: nothing left
/// to show), or the page built from its data.
class LibraryDetailBody<T extends Object> extends ConsumerWidget {
  const LibraryDetailBody({
    super.key,
    required this.page,
    required this.what,
    required this.notFound,
    required this.builder,
  });

  final ProviderListenable<AsyncValue<T?>>? page;

  /// What is read, for the log ("the album").
  final String what;
  final Widget notFound;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = this.page;
    final Widget body;
    if (ref.watch(libraryDatabaseProvider) == null) {
      body = const SongsEmptyView(kind: SongsEmptyKind.unavailable);
    } else if (page == null) {
      body = notFound;
    } else {
      ref.listen(page, (previous, next) {
        if (next.hasError && !(previous?.hasError ?? false)) {
          _log.severe(
            'Reading $what failed',
            _underlying(next.error),
            next.stackTrace,
          );
        }
      });
      body = ref
          .watch(page)
          .when(
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const LibraryLoading(),
            error: (error, stackTrace) =>
                const SongsEmptyView(kind: SongsEmptyKind.unavailable),
            data: (data) => data == null ? notFound : builder(data),
          );
    }
    return PageMaterial(child: body);
  }
}

/// The errors a parallel read failed with (`(a, b).wait` wraps them), so the
/// log shows the database error itself; both when both reads failed.
Object? _underlying(Object? error) {
  if (error is! ParallelWaitError) return error;
  final errors = error.errors;
  if (errors is! (Object?, Object?)) return error;
  final failed = [errors.$1, errors.$2].nonNulls.toList();
  return failed.length == 1 ? failed.single : failed;
}
