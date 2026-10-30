import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'add_repository_dialog.dart';
import 'remove_repository_dialog.dart';
import 'repo_error_text.dart';

final _log = Logger('lyrics_plugin_store');

/// Room under the last row so the floating button never covers its trash can.
const _fabClearance = 88.0;

/// The added repositories: name, address and a trash can each, a "!" mark
/// for one whose last fetch failed, and a button to add another. Going back
/// to the store is the router's job.
class RepositoriesPage extends ConsumerWidget {
  const RepositoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final available = ref.watch(lyricsPluginReposControllerProvider) != null;
    final repos = ref.watch(lyricsPluginReposProvider);
    return PageScaffold(
      title: l10n.lyricsStoreReposTitle,
      body: !available
          ? Center(child: Text(l10n.lyricsStoreUnavailable))
          : Stack(
              children: [
                Positioned.fill(
                  child: repos.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) =>
                        Center(child: Text(l10n.lyricsStoreLoadFailed)),
                    data: (list) => list.isEmpty
                        ? Center(child: Text(l10n.lyricsStoreReposEmpty))
                        : _RepoList(repos: list),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FloatingActionButton(
                    heroTag: null,
                    tooltip: l10n.lyricsStoreAddRepository,
                    onPressed: () => showAddRepositoryDialog(context),
                    child: Icon(
                      AppIcons.add,
                      semanticLabel: l10n.lyricsStoreAddRepository,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RepoList extends ConsumerWidget {
  const _RepoList({required this.repos});

  final List<PluginRepo> repos;

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PluginRepo repo,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = ref.read(lyricsPluginReposControllerProvider);
    if (controller == null) return;
    if (!await confirmRemoveRepository(context, repo.name)) return;
    try {
      await controller.remove(repo.url);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          appSnackBar(
            kind: AppSnackBarKind.success,
            title: l10n.lyricsStoreRepoRemoved(repo.name),
          ),
        );
    } on Object catch (error, stackTrace) {
      _log.warning('Removing a repository failed', error, stackTrace);
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.lyricsStoreRepoRemoveFailed(repo.name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, _fabClearance),
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final repo in repos)
                    ListTile(
                      key: ValueKey(repo.url),
                      leading: repo.error == null
                          ? const Icon(Icons.dns_outlined)
                          : Tooltip(
                              message: l10n.lyricsStoreRepoErrorTooltip(
                                repoLoadReasonText(l10n, repo.error!),
                              ),
                              child: CircleAvatar(
                                backgroundColor: colors.errorContainer,
                                foregroundColor: colors.onErrorContainer,
                                child: const Text('!'),
                              ),
                            ),
                      title: Text(repo.name),
                      subtitle: Text(repo.url),
                      trailing: IconButton(
                        tooltip: l10n.lyricsStoreRepoRemoveTooltip,
                        icon: Icon(
                          AppIcons.deleteOutline,
                          semanticLabel: l10n.lyricsStoreRepoRemoveTooltip,
                        ),
                        onPressed: () => _remove(context, ref, repo),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
