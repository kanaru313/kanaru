import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_icon.dart';

import 'repo_test_support.dart';

Uint8List _png(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setAll(0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  data.setUint32(12, 0x49484452);
  data.setUint32(16, width);
  data.setUint32(20, height);
  return bytes;
}

void main() {
  late TestServer server;
  setUp(() async => server = await TestServer.start());
  tearDown(() => server.close());

  Future<Uint8List?> fetch(Uint8List body, {int status = 200}) {
    server.handler = (r) async {
      r.response.statusCode = status;
      r.response.add(body);
      await r.response.close();
    };
    return fetchCatalogIcon(
      RepoHttp(),
      Uri.parse('http://127.0.0.1:${server.port}/i.png'),
      catalogKind: RepoAddressKind.local,
    );
  }

  test('a small PNG is returned', () async {
    final png = _png(64, 64);
    expect(await fetch(png), png);
  });

  test('a PNG over 256x256, not a PNG, too big or missing give null', () async {
    expect(await fetch(_png(512, 512)), isNull);
    expect(await fetch(Uint8List.fromList(List.filled(40, 1))), isNull);
    expect(await fetch(Uint8List(repoIconMaxBytes + 1)), isNull);
    expect(await fetch(Uint8List(0), status: 404), isNull);
  });

  test('a refused address gives null', () async {
    final icon = await fetchCatalogIcon(
      RepoHttp(),
      Uri.parse('http://127.0.0.1:${server.port}/i.png'),
      catalogKind: RepoAddressKind.public,
    );
    expect(icon, isNull);
    expect(server.requests, isEmpty);
  });
}
