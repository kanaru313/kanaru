import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';

void main() {
  test('starts empty; every report is a new state, even a repeat', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = <PluginNeedsConfigNotice?>[];
    container.listen(
      pluginNeedsConfigNoticesProvider,
      (_, next) => seen.add(next),
    );
    expect(container.read(pluginNeedsConfigNoticesProvider), isNull);

    final notices = container.read(pluginNeedsConfigNoticesProvider.notifier);
    notices.report('p1', 'Demo', PluginKind.lyrics);
    notices.report('p1', 'Demo', PluginKind.lyrics);

    expect(seen, hasLength(2));
    expect(seen.map((n) => n!.seq), [1, 2]);
    expect(seen.last!.installId, 'p1');
    expect(seen.last!.name, 'Demo');
    expect(seen.last!.kind, PluginKind.lyrics);
  });
}
