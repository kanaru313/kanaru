import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/repo/installed_plugin_languages_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_limits.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';

LyricsPluginRecord record(
  String id, {
  String? packageDir,
  bool removed = false,
}) => LyricsPluginRecord(
  kind: PluginKind.lyrics,
  installId: id,
  name: id,
  version: 1,
  apiVersion: 1,
  hosts: const [],
  config: const [],
  packageDir: packageDir ?? '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: 1,
  updatedAt: 1,
  removedAt: removed ? 5 : null,
);

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('plugin-langs'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<List<String>> read(String content) async {
    File('${tmp.path}/plugin.json').writeAsStringSync(content);
    return readInstalledPluginLanguages(tmp);
  }

  group('readInstalledPluginLanguages', () {
    test('reads metadata.languages as keys', () async {
      expect(
        await read(
          jsonEncode({
            'metadata': {
              'languages': ['vi', 'ja'],
            },
          }),
        ),
        ['vie', 'jpn'],
      );
    });

    test('tolerates a BOM', () async {
      expect(
        await read(
          '﻿${jsonEncode({
            'metadata': {
              'languages': ['vi'],
            },
          })}',
        ),
        ['vie'],
      );
    });

    test('missing, garbled, wrong shape and no metadata are global', () async {
      expect(await readInstalledPluginLanguages(tmp), isEmpty);
      expect(await read('{not json'), isEmpty);
      expect(await read('[]'), isEmpty);
      expect(await read('{"metadata": 3}'), isEmpty);
      expect(await read('{"metadata": {}}'), isEmpty);
      expect(await read('{"metadata": {"languages": "vi"}}'), isEmpty);
    });

    test('an oversized file is global', () async {
      final pad = ' ' * (maxPluginManifestBytes + 1);
      expect(await read('{"metadata": {"languages": ["vi"]}}$pad'), isEmpty);
    });
  });

  group('installedPluginLanguagesProvider', () {
    ProviderContainer container(String? dataDir, List<LyricsPluginRecord> rs) {
      final c = ProviderContainer(
        overrides: [
          lyricsPluginDataDirectoryProvider.overrideWithValue(dataDir),
          pluginStoreRawInputProvider.overrideWithValue(
            AsyncData(PluginStoreInput(records: rs, repos: const [])),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    void write(String dir, String languagesJson) {
      Directory('${tmp.path}/plugins/lyrics/$dir').createSync(recursive: true);
      File('${tmp.path}/plugins/lyrics/$dir/plugin.json')
          .writeAsStringSync('{"metadata": {"languages": $languagesJson}}');
    }

    test('maps install ids to the languages of their package', () async {
      final recs = [
        record('plugin-aaaaaaaaaaa1'),
        record('plugin-aaaaaaaaaaa2'),
        record('plugin-aaaaaaaaaaa3'),
        record('plugin-aaaaaaaaaaa4', removed: true),
        record('bad', packageDir: '../escape'),
      ];
      write('plugin-aaaaaaaaaaa1/v1-1', '["vi"]');
      write('plugin-aaaaaaaaaaa2/v1-1', '["*"]');
      write('plugin-aaaaaaaaaaa4/v1-1', '["vi"]');
      final c = container(tmp.path, recs);
      final map = await c.read(installedPluginLanguagesProvider.future);
      expect(map, {
        'plugin-aaaaaaaaaaa1': ['vie'],
      });
    });

    test('is empty without a data folder', () async {
      final c = container(null, [record('plugin-aaaaaaaaaaa1')]);
      expect(await c.read(installedPluginLanguagesProvider.future), isEmpty);
    });
  });
}
