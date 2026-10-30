import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_registry.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

void main() {
  test('cancelAll cancels the runs of one plugin and waits for them', () async {
    final registry = PluginRunRegistry();
    final first = PluginCancel();
    final second = PluginCancel();
    final other = PluginCancel();
    final endFirst = registry.register('plugin-a', first)!;
    final endSecond = registry.register('plugin-a', second)!;
    registry.register('plugin-b', other);
    first.addListener(() => Future.microtask(endFirst));
    expect(registry.runningCount('plugin-a'), 2);

    var finished = false;
    final waiting = registry.cancelAll('plugin-a').then((_) => finished = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(first.isCancelled, isTrue);
    expect(second.isCancelled, isTrue);
    expect(other.isCancelled, isFalse);
    expect(finished, isFalse, reason: 'the second run has not ended yet');
    endSecond();
    await waiting;
    expect(finished, isTrue);
    expect(registry.runningCount('plugin-a'), 0);
    expect(registry.runningCount('plugin-b'), 1);
  });

  test('cancelAll gives up after the wait', () async {
    final registry = PluginRunRegistry(
      cancelWait: const Duration(milliseconds: 50),
    );
    final cancel = PluginCancel();
    registry.register('plugin-a', cancel);
    final watch = Stopwatch()..start();
    await registry.cancelAll('plugin-a');
    expect(cancel.isCancelled, isTrue);
    expect(watch.elapsedMilliseconds, inInclusiveRange(40, 900));
  });

  test('unregister is idempotent and empties the plugin', () async {
    final registry = PluginRunRegistry();
    final end = registry.register('plugin-a', PluginCancel())!;
    end();
    end();
    expect(registry.runningCount('plugin-a'), 0);
    await registry.cancelAll('plugin-a');
  });

  test('a blocked plugin refuses new runs until unblocked', () {
    final registry = PluginRunRegistry();
    registry.block('plugin-a');
    registry.block('plugin-a');
    expect(registry.register('plugin-a', PluginCancel()), isNull);
    expect(registry.register('plugin-b', PluginCancel()), isNotNull);
    registry.unblock('plugin-a');
    expect(registry.isBlocked('plugin-a'), isTrue, reason: 'blocks nest');
    registry.unblock('plugin-a');
    expect(registry.register('plugin-a', PluginCancel()), isNotNull);
  });
}
