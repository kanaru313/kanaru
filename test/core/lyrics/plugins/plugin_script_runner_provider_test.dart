import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_script_runner.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_script_runner_provider.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_config_field.dart';

import 'plugin_provider_env.dart';

void main() {
  test('a blocked run reports to the notices provider', () async {
    final env = await PluginProviderEnv.create();
    addTearDown(env.dispose);
    final record = await env.install(
      name: 'Needy',
      config: const [
        PluginConfigField(
          key: 'apiKey',
          title: 'Key',
          mode: PluginConfigMode.input,
          inputFormat: PluginInputFormat.secret,
          required: true,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(env.db),
        lyricsPluginDataDirectoryProvider.overrideWithValue(
          env.store.dataDir.path,
        ),
        pluginRuntimeProvider.overrideWithValue(env.runtime),
        lyricsPluginsControllerProvider.overrideWithValue(env.controller),
      ],
    );
    addTearDown(container.dispose);

    final runner = container.read(pluginScriptRunnerProvider)!;
    await expectLater(
      runner.run<void>(
        installId: record.installId,
        script: PluginScript.search,
        input: const {'title': 't'},
        http: countingHttp(),
        read: (_, _) {},
      ),
      throwsA(
        isA<LyricsSourceSkipped>().having(
          (e) => e.needsConfig,
          'needsConfig',
          true,
        ),
      ),
    );

    final notice = container.read(pluginNeedsConfigNoticesProvider);
    expect(notice?.installId, record.installId);
    expect(notice?.name, 'Needy');
    expect(env.runtime.requests, isEmpty);
  });
}
