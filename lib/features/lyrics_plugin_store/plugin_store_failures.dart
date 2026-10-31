import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/plugin_catalog.dart';
import '../../core/lyrics/plugins/repo/repo_operation_results.dart';
import '../../l10n/l10n.dart';
import 'catalog_mismatch_lines.dart';
import 'install_problem_dialog.dart';
import 'install_problem_text.dart';
import 'plugin_store_messages.dart';

/// What a plugin install or update was about, for the messages.
typedef StoreSubject = ({
  String name,
  String? repoName,
  PluginCatalogEntry? entry,
});

/// Shows why an install, update or file install did not happen: a dialog
/// while the screen is still there, otherwise an error snackbar with the same
/// text.
class StoreFailures {
  StoreFailures(this._context, this._messages) : _l10n = _context.l10n;

  final BuildContext _context;
  final StoreMessages _messages;
  final AppLocalizations _l10n;

  /// Reports [failed]. [retry] runs when the user asks to refresh the list and
  /// try again after a mismatch.
  Future<void> failed(
    RepoPluginFailed failed,
    StoreSubject subject,
    Future<void> Function() retry,
  ) async {
    // An install that joined a running update, or an update that was not
    // needed: nothing went wrong.
    if (failed.failure == RepoPluginFailure.noNewerVersion) return;
    final repoLine = subject.repoName == null
        ? subject.name
        : _l10n.lyricsStoreInstallFailedRepo(subject.name, subject.repoName!);
    if (needsNewerApp(failed)) {
      if (_context.mounted) {
        await showNeedsNewerAppDialog(_context, subject.name);
      } else {
        _messages.error(_l10n.lyricsStoreNeedsNewerBody(subject.name));
      }
      return;
    }
    if (failed.failure == RepoPluginFailure.catalogMismatch) {
      if (!_context.mounted) {
        _messages.error(_l10n.lyricsStoreFailMismatch);
        return;
      }
      final again = await showCatalogMismatchDialog(
        _context,
        subject: repoLine,
        differences: mismatchLines(_l10n, failed, subject.entry),
      );
      if (again) await retry();
      return;
    }
    await problem(repoLine, [repoFailureText(_l10n, failed)]);
  }

  /// The "could not install" dialog, or a snackbar when the screen is gone.
  Future<void> problem(String subject, List<String> reasons) async {
    if (_context.mounted) {
      await showInstallProblemDialog(
        _context,
        subject: subject,
        reasons: reasons,
      );
    } else {
      _messages.error(reasons.join('\n'));
    }
  }
}
