import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/has_source_plugins.dart';
import 'package:kanaru/core/sources/source_plugin_records.dart';

import 'online_test_support.dart';

void main() {
  bool has(AsyncValue<List<LyricsPluginRecord>> records) {
    final container = ProviderContainer(
      overrides: onlineOverrides(testRecords(records)),
    );
    addTearDown(container.dispose);
    return container.read(hasSourcePluginsProvider);
  }

  test('is true with a source plugin', () {
    expect(has(AsyncValue.data([sourceRecord()])), isTrue);
  });

  test('is false with none, while loading and on a read error', () {
    expect(has(const AsyncValue.data([])), isFalse);
    expect(has(const AsyncValue.loading()), isFalse);
    expect(has(AsyncValue.error(StateError('x'), StackTrace.empty)), isFalse);
  });
}
