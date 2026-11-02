import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/repo/installed_plugin_languages_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_providers.dart';

void main() {
  test('installed package languages reach the rows of the view', () async {
    const id = 'plugin-aaaaaaaaaaa1';
    final record = LyricsPluginRecord(
      kind: PluginKind.lyrics,
      installId: id,
      name: 'Mine',
      version: 1,
      apiVersion: 1,
      hosts: const [],
      config: const [],
      packageDir: '$id/v1-1',
      sourceKind: LyricsPluginSourceKind.file,
      sourceName: 'x.zip',
      installedAt: 1,
      updatedAt: 1,
    );
    final c = ProviderContainer(
      overrides: [
        pluginStoreRawInputProvider.overrideWithValue(
          AsyncData(PluginStoreInput(records: [record], repos: const [])),
        ),
        installedPluginLanguagesProvider.overrideWith(
          (ref) async => {
            id: ['vie'],
          },
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(pluginStoreViewProvider(null), (_, _) {});
    addTearDown(sub.close);
    await c.read(installedPluginLanguagesProvider.future);
    final view = c.read(pluginStoreViewProvider(null)).requireValue;
    expect(view.installed.single.languages, ['vie']);
  });
}
