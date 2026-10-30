import 'package:logging/logging.dart';

import '../lyrics_plugin_record.dart';
import 'repo_operation_results.dart';

final _log = Logger('lyrics_plugin_repos');

/// Updates the plugins [listDue] returns, one after the other, through
/// [update]. A failed plugin is a failed outcome and the run goes on; a plugin
/// that was updated or removed by someone else since the list was made is
/// skipped without an outcome. Each outcome is passed to [emit] as soon as it
/// is known. When [listDue] throws the run is empty. Never throws.
Future<List<RepoUpdateOutcome>> runUpdateAll({
  required Future<List<LyricsPluginRecord>> Function() listDue,
  required Future<RepoPluginResult> Function(String installId) update,
  required void Function(RepoUpdateOutcome outcome) emit,
}) async {
  final List<LyricsPluginRecord> due;
  try {
    due = await listDue();
  } on Object catch (error) {
    _log.warning('Listing plugin updates failed: ${error.runtimeType}');
    return const [];
  }
  final outcomes = <RepoUpdateOutcome>[];
  for (final record in due) {
    final result = await update(record.installId);
    if (result is RepoPluginFailed &&
        (result.failure == RepoPluginFailure.noNewerVersion ||
            result.failure == RepoPluginFailure.gone)) {
      continue;
    }
    final outcome = RepoUpdateOutcome(record.installId, record.name, result);
    outcomes.add(outcome);
    emit(outcome);
  }
  return List.unmodifiable(outcomes);
}
