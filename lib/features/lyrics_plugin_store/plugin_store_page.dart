import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'plugin_store_actions.dart';
import 'plugin_store_banner.dart';
import 'plugin_store_empty.dart';
import 'plugin_store_menu.dart';
import 'plugin_store_providers.dart';
import 'plugin_store_sections.dart';
import 'plugin_store_source_chips.dart';

/// The plugin store: what the added repositories offer next to the plugins
/// already installed, with search, a source filter, and one-tap install,
/// update and uninstall. Opening it fetches every repository once.
///
/// The page navigates only through its callbacks, so the router decides where
/// they lead.
class PluginStorePage extends ConsumerStatefulWidget {
  const PluginStorePage({
    super.key,
    required this.onOpenInstalled,
    required this.onOpenCatalogItem,
    required this.onOpenRepositories,
  });

  /// A row of an installed plugin was tapped.
  final void Function(String installId) onOpenInstalled;

  /// A row of a plugin that is not installed was tapped.
  final void Function(String repoUrl, String slug) onOpenCatalogItem;

  /// "Repository (N)" was chosen in the menu.
  final VoidCallback onOpenRepositories;

  @override
  ConsumerState<PluginStorePage> createState() => _PluginStorePageState();
}

class _PluginStorePageState extends ConsumerState<PluginStorePage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame: the actions read the surrounding widgets.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(PluginStoreActions(context).refreshAll());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(pluginStoreViewProvider);
    final data = view.value;
    return PageScaffold(
      title: l10n.lyricsStoreTitle,
      actions: [
        if (data != null && data.available)
          PluginStoreMenu(
            repositoryCount: data.sources.length,
            onOpenRepositories: widget.onOpenRepositories,
          ),
      ],
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.lyricsStoreLoadFailed),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(lyricsPluginReposProvider),
                child: Text(l10n.lyricsStoreRetry),
              ),
            ],
          ),
        ),
        data: (view) {
          if (!view.available) {
            return Center(child: Text(l10n.lyricsStoreUnavailable));
          }
          final nothingAtAll =
              view.isEmpty && view.sources.isEmpty && !view.hasFileSource;
          if (nothingAtAll) return const PluginStoreEmpty();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  PluginStoreBanner(failing: view.failingRepos),
                  _SearchField(controller: _search),
                  PluginStoreSourceChips(view: view),
                  PluginStoreSections(
                    view: view,
                    onOpenInstalled: widget.onOpenInstalled,
                    onOpenCatalogItem: widget.onOpenCatalogItem,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: ref.read(pluginStoreSearchProvider.notifier).set,
        decoration: InputDecoration(
          hintText: context.l10n.lyricsStoreSearchHint,
          prefixIcon: const Icon(AppIcons.search),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          isDense: true,
        ),
      ),
    );
  }
}
