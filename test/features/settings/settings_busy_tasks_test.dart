import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/settings_busy_tasks.dart';

void main() {
  test('a task starts once until it finishes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tasks = container.read(settingsBusyTasksProvider.notifier);

    expect(tasks.start(SettingsTask.coverCache), isTrue);
    expect(tasks.start(SettingsTask.coverCache), isFalse);
    expect(tasks.start(SettingsTask.listenHistory), isTrue);
    expect(container.read(settingsBusyTasksProvider), {
      SettingsTask.coverCache,
      SettingsTask.listenHistory,
    });

    tasks.finish(SettingsTask.coverCache);
    expect(container.read(settingsBusyTasksProvider), {
      SettingsTask.listenHistory,
    });
    expect(tasks.start(SettingsTask.coverCache), isTrue);
  });

  test('the state stays while nothing listens', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(settingsBusyTasksProvider.notifier)
        .start(SettingsTask.excludedFolders);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(settingsBusyTasksProvider), {
      SettingsTask.excludedFolders,
    });
  });

  test('finishing after the container is disposed does not throw', () {
    final container = ProviderContainer();
    final tasks = container.read(settingsBusyTasksProvider.notifier)
      ..start(SettingsTask.coverCache);
    container.dispose();
    expect(() => tasks.finish(SettingsTask.coverCache), returnsNormally);
  });
}
