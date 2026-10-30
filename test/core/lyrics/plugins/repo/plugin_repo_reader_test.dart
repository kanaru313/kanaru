import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo_reader.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';

import 'repo_controller_env.dart';

void main() {
  late RepoEnv env;

  setUp(() async {
    env = await RepoEnv.create();
    env.serveCatalog([entryJson()]);
    await env.repos.add(catalogUrl);
  });
  tearDown(() => env.dispose());

  Future<List<LyricsPluginRepoRow>> rows() =>
      env.store.db.watchLyricsPluginRepos().first;

  test('an unchanged catalog text is not parsed again', () async {
    final reader = PluginRepoReader();
    final first = reader.readAll(await rows()).single;
    final second = reader.readAll(await rows()).single;
    expect(identical(first.catalog, second.catalog), isTrue);
    expect(first.kind, RepoAddressKind.local);
  });

  test('a changed text is parsed, and a removed repo is forgotten', () async {
    final reader = PluginRepoReader();
    final before = reader.readAll(await rows()).single;
    env.serveCatalog([entryJson(version: 9)]);
    await env.repos.refreshAll();
    final after = reader.readAll(await rows()).single;
    expect(identical(before.catalog, after.catalog), isFalse);
    expect(after.catalog!.entries.single.version, 9);
    await env.repos.remove(catalogUrl);
    expect(reader.readAll(await rows()), isEmpty);
  });

  test(
    'the reason of a refused address is attached to its kind only',
    () async {
      env.resolver.answers['repo.lan'] = [
        ['93.184.216.34'],
      ];
      final refreshed = await env.repos.refreshAll();
      expect(refreshed.single.error!.reason, isNotNull);
      // The table keeps the kind; the controller's stream adds the reason.
      expect((await rows()).single.lastError, 'blockedAddress');
      final repo = (await env.repos.watchRepos().first).single;
      expect(repo.error!.kind, RepoFetchErrorKind.blockedAddress);
      expect(repo.error!.reason, refreshed.single.error!.reason);
      // A plain reader (a restart) knows the kind only.
      final cold = PluginRepoReader().readAll(await rows()).single;
      expect(cold.error!.kind, RepoFetchErrorKind.blockedAddress);
      expect(cold.error!.reason, isNull);
    },
  );
}
