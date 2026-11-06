import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/source_plugin_drops.dart';

void main() {
  test('hands every added install id to the listeners', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final drops = container.read(sourcePluginDropsProvider);
    final seen = <String>[];
    final a = drops.stream.listen(seen.add);
    final b = drops.stream.listen(seen.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);

    drops
      ..add('plugin-aaaaaaaaaaaa')
      ..add('plugin-bbbbbbbbbbbb');
    await Future<void>.delayed(Duration.zero);

    expect(seen, [
      'plugin-aaaaaaaaaaaa',
      'plugin-aaaaaaaaaaaa',
      'plugin-bbbbbbbbbbbb',
      'plugin-bbbbbbbbbbbb',
    ]);
  });

  test('adding after the container is gone does nothing', () {
    final container = ProviderContainer();
    final drops = container.read(sourcePluginDropsProvider);
    container.dispose();
    expect(() => drops.add('plugin-aaaaaaaaaaaa'), returnsNormally);
  });
}
