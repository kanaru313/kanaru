import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/player/track.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/sources/source_plugin_runner.dart';
import 'remote_track_builder.dart';

/// What the Online screen shows for the last search.
sealed class OnlineSearchState {
  const OnlineSearchState();
}

/// No search yet.
class OnlineSearchIdle extends OnlineSearchState {
  const OnlineSearchIdle();
}

/// A search of [installId] is running.
class OnlineSearchLoading extends OnlineSearchState {
  const OnlineSearchLoading(this.installId, this.query);

  final String installId;
  final String query;
}

/// The first page of results: every shown result as a remote track.
class OnlineSearchResults extends OnlineSearchState {
  const OnlineSearchResults(this.installId, this.query, this.tracks);

  final String installId;
  final String query;
  final List<Track> tracks;
}

/// The search found nothing.
class OnlineSearchEmpty extends OnlineSearchState {
  const OnlineSearchEmpty(this.installId, this.query);

  final String installId;
  final String query;
}

/// The search failed; [message] is the plugin's own text, often empty.
class OnlineSearchFailed extends OnlineSearchState {
  const OnlineSearchFailed(
    this.installId,
    this.query,
    this.kind, {
    this.message = '',
  });

  final String installId;
  final String query;
  final SourceFailureKind kind;
  final String message;
}

/// The plugin may send nothing until its notice is accepted; [query] is the
/// search that waits for it.
class OnlineSearchConsent extends OnlineSearchState {
  const OnlineSearchConsent(this.installId, this.query);

  final String installId;
  final String query;
}

/// Runs the searches of the Online screen. Not auto-disposed, so the results
/// survive a switch to another sidebar page. Only a call to [search] or
/// [acceptNotice] sends anything; typing never does.
class OnlineSearchController extends Notifier<OnlineSearchState> {
  /// Counts searches: a result that arrives after a newer search started (or
  /// after this notifier went away) is dropped, and its HTTP is abandoned.
  int _generation = 0;

  @override
  OnlineSearchState build() {
    ref.onDispose(() => _generation++);
    return const OnlineSearchIdle();
  }

  /// Searches the first page of [query] in the plugin [installId]. A blank
  /// query does nothing.
  Future<void> search(String installId, String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    final generation = ++_generation;
    bool superseded() => generation != _generation;
    state = OnlineSearchLoading(installId, text);
    final runner = ref.read(sourcePluginRunnerProvider);
    if (runner == null) {
      state = OnlineSearchFailed(installId, text, SourceFailureKind.internal);
      return;
    }
    OnlineSearchState next;
    try {
      final page = await runner.search(installId, text, abandoned: superseded);
      next = page.items.isEmpty
          ? OnlineSearchEmpty(installId, text)
          : OnlineSearchResults(installId, text, [
              for (final item in page.items) remoteTrackOf(installId, item),
            ]);
    } on SourceFailure catch (failure) {
      next = switch (failure.kind) {
        SourceFailureKind.notConsented => OnlineSearchConsent(installId, text),
        // The plugin is gone or the call was abandoned: nothing to report.
        SourceFailureKind.skipped => const OnlineSearchIdle(),
        _ => OnlineSearchFailed(
          installId,
          text,
          failure.kind,
          message: failure.message,
        ),
      };
    } on Object {
      next = OnlineSearchFailed(installId, text, SourceFailureKind.internal);
    }
    if (superseded()) return;
    state = next;
  }

  /// The user accepted the plugin's notice: remember it and run the search
  /// that was waiting.
  Future<void> acceptNotice() async {
    final current = state;
    if (current is! OnlineSearchConsent) return;
    ref
        .read(settingsProvider.notifier)
        .acknowledgeSourceNotice(current.installId);
    await search(current.installId, current.query);
  }

  /// Runs the last search again (the Retry button).
  Future<void> retry() async {
    final current = state;
    if (current is OnlineSearchFailed) {
      await search(current.installId, current.query);
    }
  }
}

final onlineSearchControllerProvider =
    NotifierProvider<OnlineSearchController, OnlineSearchState>(
      OnlineSearchController.new,
    );
