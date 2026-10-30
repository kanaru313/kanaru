import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

import '../package/package_test_helpers.dart';
import '../store/store_test_env.dart';
import 'repo_test_support.dart';

const catalogUrl = 'http://repo.lan:8080/plugins.json';

/// One catalog entry as JSON; [path] is relative to the catalog.
Map<String, Object?> entryJson({
  String slug = 'demo',
  String name = 'Demo',
  int version = 3,
  int apiVersion = 1,
  List<String> hosts = const ['music.example.com'],
  String path = 'demo.zip',
  String? author,
  String? icon,
}) => {
  'slug': slug,
  'name': name,
  'version': version,
  'apiVersion': apiVersion,
  'type': 'lyrics',
  'hosts': hosts,
  'path': path,
  'author': ?author,
  'icon': ?icon,
};

String catalogJson(
  List<Map<String, Object?>> entries, {
  String name = 'Official',
}) => jsonEncode({
  'metadata': {'name': name, 'author': 'someone'},
  'data': entries,
});

/// A plugin zip whose manifest has [version] and [hosts] (defaults match
/// [entryJson]).
List<int> pluginZip({
  String name = 'Demo',
  int version = 3,
  List<String> hosts = const ['music.example.com'],
  Map<String, Object?> config = const {},
}) {
  final manifest = validManifest();
  (manifest['metadata'] as Map<String, dynamic>)
    ..['name'] = name
    ..['version'] = version
    ..['hosts'] = hosts;
  if (config.isNotEmpty) manifest['config'] = config;
  return validZip(manifest: manifest);
}

/// A real plugins controller on an in-memory database, a repos controller on
/// top, and a loopback server that stands for every repository host (a
/// `.lan` name resolves to a private address and the dialer goes to the
/// server).
class RepoEnv {
  RepoEnv._(this.store, this.server, this.resolver, this.dialer, this.repos);

  final StoreEnv store;
  final TestServer server;
  final FakeResolver resolver;
  final RecordingDialer dialer;
  final LyricsPluginReposController repos;

  static Future<RepoEnv> create() async {
    final store = await StoreEnv.create();
    final server = await TestServer.start();
    final resolver = FakeResolver({
      'repo.lan': [
        ['192.168.1.5'],
      ],
      'example.com': [
        [fakePublicIp],
      ],
    });
    final dialer = RecordingDialer(server);
    final repos = LyricsPluginReposController(
      db: store.db,
      plugins: store.controller,
      reader: PluginPackageReader(FakeRuntime()),
      http: RepoHttp(resolver: resolver.call, dialer: dialer.call),
    );
    final env = RepoEnv._(store, server, resolver, dialer, repos);
    server.handler = env._serve;
    return env;
  }

  /// Bodies by request path; an unknown path is 404.
  final routes = <String, List<int>>{};

  /// Paths that answer with this status instead of their body.
  final failing = <String, int>{};

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    final status = failing[path];
    if (status != null) {
      request.response.statusCode = status;
    } else if (routes[path] case final body?) {
      request.response.add(body);
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  }

  void serveCatalog(List<Map<String, Object?>> entries, {String? name}) {
    routes['/plugins.json'] = utf8.encode(
      name == null ? catalogJson(entries) : catalogJson(entries, name: name),
    );
  }

  Future<void> dispose() async {
    await server.close();
    await store.dispose();
  }
}
