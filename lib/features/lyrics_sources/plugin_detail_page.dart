import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../core/lyrics/plugins/plugin_data_stats_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_plugins/plugin_record_text.dart';
import '../../shared/lyrics_plugins/plugin_uninstall_dialog.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'plugin_config_form.dart';
import 'plugin_config_save.dart';
import 'plugin_data_rows.dart';
import 'plugin_icon.dart';
import 'plugin_info_section.dart';
import 'plugin_update_banner.dart';

final _log = Logger('lyrics_sources');

/// The page of one installed plugin: switch, details, settings form, data.
/// The trash button in the header uninstalls it. When the plugin is gone (it
/// was uninstalled elsewhere) the page says so and offers the way back.
class PluginDetailPage extends ConsumerStatefulWidget {
  const PluginDetailPage({super.key, required this.installId});

  final String installId;

  @override
  ConsumerState<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends ConsumerState<PluginDetailPage> {
  /// Our own uninstall is running. The record leaves the database before the
  /// folders and logs are deleted; until it returns the page stays blank
  /// instead of flashing "no longer installed".
  bool _uninstalling = false;

  String get _id => widget.installId;

  Future<void> _uninstall(LyricsPluginRecord record) async {
    // Taken before the awaits: the page may close meanwhile.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final controller = ref.read(lyricsPluginsControllerProvider);
    if (controller == null) return;
    PluginDataStats stats;
    try {
      // Read again: lookups may have saved lyrics since the page opened.
      stats = await ref.refresh(pluginDataStatsProvider(_id).future);
    } catch (error, stackTrace) {
      _log.warning('Reading the plugin data sizes failed', error, stackTrace);
      stats = (storageBytes: 0, foundCount: 0, textBytes: 0);
    }
    if (!mounted) return;
    if (!await confirmPluginUninstall(context, record, stats)) return;
    if (!mounted) return;
    setState(() => _uninstalling = true);
    LyricsPluginUninstall outcome;
    try {
      outcome = await controller.uninstall(_id);
    } catch (error, stackTrace) {
      _log.warning('Uninstalling a plugin failed', error, stackTrace);
      if (mounted) setState(() => _uninstalling = false);
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.pluginUninstallFailed(record.name),
        ),
      );
      return;
    }
    if (mounted) setState(() => _uninstalling = false);
    // The user may have gone elsewhere while the files were deleted.
    final here = router.routeInformationProvider.value.uri.path;
    if (here == Uri.parse(lyricsPluginRoute(_id)).path) {
      router.go(lyricsSourcesRoute);
    }
    // Already gone before we got there: nothing was removed by this click.
    if (outcome == LyricsPluginUninstall.missing ||
        outcome == LyricsPluginUninstall.alreadyRemoved) {
      return;
    }
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        title: l10n.pluginUninstalled(record.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loaded = ref.watch(lyricsSourcesLoadedProvider);
    final failed = ref.watch(lyricsSourcesInputProvider).hasError;
    final entry = ref
        .watch(lyricsSourcesProvider)
        .where((e) => e.id == _id && e.record != null)
        .firstOrNull;
    if (entry == null) {
      return PageScaffold(
        title: l10n.lyricsSourcesTitle,
        body: _uninstalling
            ? const SizedBox.shrink()
            : failed
            ? _LoadFailed(
                onRetry: () => ref.invalidate(lyricsSourcesInputProvider),
              )
            // Until the first answer a missing plugin is not yet "gone".
            : (loaded ? const _Gone() : const SizedBox.shrink()),
      );
    }
    final record = entry.record!;
    final controller = ref.watch(lyricsPluginsControllerProvider);
    return PageScaffold(
      title: record.name,
      actions: [
        IconButton(
          tooltip: l10n.pluginUninstall,
          // The tooltip names the button for the mouse; the label names it for
          // screen readers.
          icon: Icon(
            AppIcons.deleteOutline,
            semanticLabel: l10n.pluginUninstall,
          ),
          onPressed: controller == null || _uninstalling
              ? null
              : () => _uninstall(record),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                leading: PluginIcon(record: record, size: 48),
                title: Text(
                  record.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(pluginByline(l10n, record)),
                trailing: Semantics(
                  label: record.name,
                  child: Switch(
                    value: entry.enabled,
                    onChanged: controller == null
                        ? null
                        : (on) =>
                              unawaited(setLyricsSourceOn(controller, _id, on)),
                  ),
                ),
              ),
              PluginUpdateBanner(record: record),
              PluginInfoSection(record: record),
              PluginConfigForm(record: record),
              PluginDataRows(record: record),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pluginSourcesLoadFailed),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.pluginRetry)),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pluginGone),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.go(lyricsSourcesRoute),
            child: Text(l10n.lyricsSourcesTitle),
          ),
        ],
      ),
    );
  }
}
