import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';

final _log = Logger('lyrics_plugin_store');

/// The snackbars of the store. Built from a widget's [context]; the messenger,
/// providers and texts are taken at once so they still work after the screen
/// closed.
class StoreMessages {
  StoreMessages(BuildContext context)
    : _container = ProviderScope.containerOf(context),
      _messenger = ScaffoldMessenger.of(context),
      _l10n = context.l10n;

  final ProviderContainer _container;
  final ScaffoldMessengerState _messenger;
  final AppLocalizations _l10n;

  /// A plain snackbar; replaces the one on screen.
  void message(String title, {AppSnackBarKind kind = AppSnackBarKind.success}) {
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(kind: kind, title: title));
  }

  void error(String title) => message(title, kind: AppSnackBarKind.error);

  /// "Đã cài (name)" with "Hoàn tác", which uninstalls the plugin again. Only
  /// for a new or revived plugin: undoing an update would uninstall a plugin
  /// the user already had.
  void installed(LyricsPluginRecord record) {
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.success,
          title: _l10n.lyricsStoreInstalled(record.name),
          persist: false,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: _l10n.lyricsStoreUndo,
            onPressed: () => _undo(record),
          ),
        ),
      );
  }

  Future<void> _undo(LyricsPluginRecord record) async {
    final plugins = _container.read(lyricsPluginsControllerProvider);
    if (plugins == null) return;
    try {
      final result = await plugins.undoInstall(record.installId);
      // The plugin is gone either way; only say so when there was nothing to
      // undo.
      if (result == LyricsPluginUninstall.missing ||
          result == LyricsPluginUninstall.alreadyRemoved) {
        message(
          _l10n.lyricsStoreAlreadyGone(record.name),
          kind: AppSnackBarKind.info,
        );
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Undoing an install failed', error, stackTrace);
      this.error(_l10n.lyricsStoreUndoFailed);
    }
  }
}
