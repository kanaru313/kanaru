import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A clear or folder edit that can be in flight.
enum SettingsTask {
  coverCache,
  onlineLyricsCache,
  translationCache,
  listenHistory,
  libraryFolders,
  excludedFolders,
}

/// Clears and folder edits in flight; outlives the rows that start them, so a
/// page opened again mid-task shows it busy.
class SettingsBusyTasks extends Notifier<Set<SettingsTask>> {
  @override
  Set<SettingsTask> build() => const {};

  /// Marks [task] busy; false when it already is.
  bool start(SettingsTask task) {
    if (state.contains(task)) return false;
    state = {...state, task};
    return true;
  }

  /// Safe after the container is disposed (a clear that outlives the app's
  /// scope): then there is nothing left to update.
  void finish(SettingsTask task) {
    if (!ref.mounted) return;
    state = {...state}..remove(task);
  }
}

// Not autoDispose: the state must live while no row listens.
final settingsBusyTasksProvider =
    NotifierProvider<SettingsBusyTasks, Set<SettingsTask>>(
      SettingsBusyTasks.new,
    );
