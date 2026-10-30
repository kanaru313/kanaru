import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

Map<String, Object?> _entry([Map<String, Object?> over = const {}]) => {
  'slug': 'netease',
  'name': 'NetEase Cloud Music',
  'version': 3,
  'apiVersion': 1,
  'type': 'lyrics',
  'hosts': ['music.163.com'],
  'path': 'https://cdn.example.com/netease/plugin.zip',
  ...over,
};

Uint8List _json(Object? value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Map<String, Object?> _catalog(List<Object?> data) => {
  'metadata': {'name': 'Kho của hieu05', 'author': 'hieu05'},
  'data': data,
};

void main() {
  final publicOrigin = (
    url: Uri.parse('https://repo.example.com/plugins.json'),
    kind: RepoAddressKind.public,
  );
  final localOrigin = (
    url: Uri.parse('http://192.168.1.5:8765/plugins.json'),
    kind: RepoAddressKind.local,
  );

  PluginCatalog parse(Object? json, [PluginCatalogOrigin? origin]) =>
      parsePluginCatalog(_json(json), origin ?? publicOrigin);

  RepoFetchErrorKind? failureOf(void Function() call) {
    try {
      call();
    } on RepoFetchException catch (e) {
      return e.kind;
    }
    return null;
  }

  test('parses a full entry', () {
    final catalog = parse(
      _catalog([
        _entry({
          'icon': 'https://cdn.example.com/netease/icon.png',
          'description': 'Lời từ NetEase',
          'author': 'hieu05',
          'hosts': ['Music.163.com ', 'interface.music.163.com'],
        }),
      ]),
    );
    expect(catalog.name, 'Kho của hieu05');
    expect(catalog.author, 'hieu05');
    expect(catalog.dropped, 0);
    final e = catalog.entries.single;
    expect(e.slug, 'netease');
    expect(e.name, 'NetEase Cloud Music');
    expect(e.version, 3);
    expect(e.apiVersion, 1);
    expect(e.hosts, ['music.163.com', 'interface.music.163.com']);
    expect(e.path, Uri.parse('https://cdn.example.com/netease/plugin.zip'));
    expect(e.icon, Uri.parse('https://cdn.example.com/netease/icon.png'));
    expect(e.description, 'Lời từ NetEase');
    expect(e.author, 'hieu05');
  });

  test('author is optional; an empty data list is a valid empty catalog', () {
    final catalog = parsePluginCatalog(
      _json({
        'metadata': {'name': 'Rỗng'},
        'data': <Object?>[],
      }),
      publicOrigin,
    );
    expect(catalog.author, '');
    expect(catalog.entries, isEmpty);
  });

  group('relative references', () {
    test('path and icon resolve against the catalog address', () {
      final catalog = parse(
        _catalog([
          _entry({'path': 'dist/netease/plugin.zip', 'icon': '../icons/n.png'}),
        ]),
        (
          url: Uri.parse('https://repo.example.com/store/plugins.json'),
          kind: RepoAddressKind.public,
        ),
      );
      final e = catalog.entries.single;
      expect(
        e.path,
        Uri.parse('https://repo.example.com/store/dist/netease/plugin.zip'),
      );
      expect(e.icon, Uri.parse('https://repo.example.com/icons/n.png'));
    });

    test('a root-relative path keeps the port of a local catalog', () {
      final catalog = parse(
        _catalog([
          _entry({'path': '/z/plugin.zip'}),
        ]),
        localOrigin,
      );
      expect(
        catalog.entries.single.path,
        Uri.parse('http://192.168.1.5:8765/z/plugin.zip'),
      );
    });
  });

  group('address rules on references', () {
    test('a public catalog drops an entry that points to a local address', () {
      for (final path in [
        'http://10.0.0.2/a.zip',
        'https://10.0.0.2/a.zip',
        'https://localhost/a.zip',
        'https://nas.lan/a.zip',
        'https://[::1]/a.zip',
        'https://169.254.169.254/a.zip',
        'http://cdn.example.com/a.zip',
        'https://user:pw@cdn.example.com/a.zip',
        'ftp://cdn.example.com/a.zip',
        'file:///etc/passwd',
      ]) {
        final catalog = parse(
          _catalog([
            _entry({'slug': 'bad', 'path': path}),
            _entry(),
          ]),
        );
        expect(catalog.entries.map((e) => e.slug), ['netease'], reason: path);
        expect(catalog.dropped, 1, reason: path);
      }
    });

    test('a bad icon only drops the icon', () {
      final catalog = parse(
        _catalog([
          _entry({'icon': 'http://10.0.0.2/i.png'}),
        ]),
      );
      expect(catalog.entries.single.icon, isNull);
      expect(catalog.dropped, 0);
    });

    test('a local catalog may point to local and to public https', () {
      final catalog = parse(
        _catalog([
          _entry({'slug': 'a', 'path': 'http://192.168.1.9:80/a.zip'}),
          _entry({'slug': 'b', 'path': 'https://cdn.example.com/b.zip'}),
          _entry({'slug': 'c', 'path': 'http://cdn.example.com/c.zip'}),
          _entry({'slug': 'd', 'path': 'http://8.8.8.8/d.zip'}),
        ]),
        localOrigin,
      );
      expect(catalog.entries.map((e) => e.slug), ['a', 'b', 'c']);
      // `c` waits for the lookup: a name may resolve to a local address.
      expect(catalog.dropped, 1);
    });
  });

  group('entry rules', () {
    test('slug pattern', () {
      final slugs = [
        'a',
        'a-b_c9',
        'x' * 64,
        'Upper',
        'has space',
        'dot.dot',
        '',
        'x' * 65,
        'ü',
      ];
      final catalog = parse(
        _catalog([
          for (final s in slugs) _entry({'slug': s}),
        ]),
      );
      expect(catalog.entries.map((e) => e.slug), ['a', 'a-b_c9', 'x' * 64]);
      expect(catalog.dropped, 6);
    });

    test('a repeated slug keeps the first one', () {
      final catalog = parse(
        _catalog([
          _entry({'name': 'First'}),
          _entry({'name': 'Second'}),
        ]),
      );
      expect(catalog.entries.single.name, 'First');
      expect(catalog.dropped, 1);
    });

    test('invalid fields drop the entry', () {
      final bad = <Map<String, Object?>>[
        {'name': ''},
        {'name': 'x' * 81},
        {'name': 5},
        {'version': 0},
        {'version': '3'},
        {'version': 2147483648},
        {'apiVersion': 0},
        {'apiVersion': 'one'},
        {'type': 'translation'},
        {'type': null},
        {'hosts': <Object?>[]},
        {'hosts': 'music.163.com'},
        {
          'hosts': ['localhost'],
        },
        {
          'hosts': ['192.168.1.1'],
        },
        {
          'hosts': ['single'],
        },
        {
          'hosts': ['ok.example.com', 5],
        },
        {'hosts': List.generate(21, (i) => 'h$i.example.com')},
        {'description': 'x' * 501},
        {'author': 'x' * 81},
        {'path': null},
        {'path': ''},
        {'path': 7},
      ];
      for (final over in bad) {
        final catalog = parse(
          _catalog([
            _entry({'slug': 'bad', ...over}),
            _entry(),
          ]),
        );
        expect(catalog.entries.map((e) => e.slug), [
          'netease',
        ], reason: '$over');
        expect(catalog.dropped, 1, reason: '$over');
      }
    });

    test('text is cleaned like manifest text', () {
      final catalog = parse(
        _catalog([
          _entry({'name': '  Net\u202EEase\u0000  '}),
        ]),
      );
      expect(catalog.entries.single.name, 'NetEase');
    });

    test('an entry that is not an object is dropped', () {
      final catalog = parse(_catalog([5, null, 'x', _entry()]));
      expect(catalog.entries, hasLength(1));
      expect(catalog.dropped, 3);
    });

    test('an entry for a newer apiVersion is kept for the store to hide', () {
      final catalog = parse(
        _catalog([
          _entry({'apiVersion': 9}),
        ]),
      );
      expect(catalog.entries.single.apiVersion, 9);
    });
  });

  group('catalog rules', () {
    test('no usable entry in a non-empty data is invalid', () {
      expect(
        failureOf(
          () => parse(
            _catalog([
              _entry({'slug': 'BAD'}),
            ]),
          ),
        ),
        RepoFetchErrorKind.invalidCatalog,
      );
      expect(
        failureOf(() => parse(_catalog([1, 2]))),
        RepoFetchErrorKind.invalidCatalog,
      );
    });

    test('at most 500 entries', () {
      List<Object?> many(int n) => [
        for (var i = 0; i < n; i++) _entry({'slug': 's$i'}),
      ];
      expect(parse(_catalog(many(500))).entries, hasLength(500));
      expect(
        failureOf(() => parse(_catalog(many(501)))),
        RepoFetchErrorKind.invalidCatalog,
      );
    });

    test('shape errors', () {
      for (final json in <Object?>[
        [],
        'text',
        {'data': <Object?>[]},
        {
          'metadata': {'name': 'x'},
        },
        {'metadata': 'x', 'data': <Object?>[]},
        {'metadata': {}, 'data': <Object?>[]},
        {
          'metadata': {'name': ''},
          'data': <Object?>[],
        },
        {
          'metadata': {'name': 'x' * 81},
          'data': <Object?>[],
        },
        {
          'metadata': {'name': 'x', 'author': 3},
          'data': <Object?>[],
        },
        {
          'metadata': {'name': 'x'},
          'data': <String, Object?>{},
        },
      ]) {
        expect(
          failureOf(() => parse(json)),
          RepoFetchErrorKind.invalidCatalog,
          reason: '$json',
        );
      }
    });

    test('not JSON or not UTF-8', () {
      expect(
        failureOf(
          () => parsePluginCatalog(
            Uint8List.fromList(utf8.encode('{nope')),
            publicOrigin,
          ),
        ),
        RepoFetchErrorKind.invalidCatalog,
      );
      expect(
        failureOf(
          () => parsePluginCatalog(
            Uint8List.fromList([0xff, 0xfe]),
            publicOrigin,
          ),
        ),
        RepoFetchErrorKind.invalidCatalog,
      );
    });

    test('a leading BOM is tolerated', () {
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF, //
        ...utf8.encode(jsonEncode(_catalog([_entry()]))),
      ]);
      expect(parsePluginCatalog(bytes, publicOrigin).entries, hasLength(1));
    });

    test('over 1 MiB is too large', () {
      expect(
        failureOf(
          () => parsePluginCatalog(
            Uint8List(repoCatalogMaxBytes + 1),
            publicOrigin,
          ),
        ),
        RepoFetchErrorKind.tooLarge,
      );
    });
  });

  group('addresses over the length limit once absolute', () {
    final longQuery = 'a' * 2040;

    test('a long path counts as a dropped entry', () {
      final catalog = parse(
        _catalog([
          _entry(),
          _entry({
            'slug': 'long',
            'path': 'https://cdn.example.com/z?$longQuery',
          }),
        ]),
        publicOrigin,
      );
      expect(catalog.entries.map((e) => e.slug), ['netease']);
      expect(catalog.dropped, 1);
    });

    test('a short relative path that resolves long is dropped too', () {
      // 2033 characters relative, but the catalog address makes it longer.
      final catalog = parse(
        _catalog([
          _entry(),
          _entry({'slug': 'rel', 'path': '/z?${'b' * 2030}'}),
        ]),
        publicOrigin,
      );
      expect(catalog.entries.map((e) => e.slug), ['netease']);
      expect(catalog.dropped, 1);
    });

    test('a long icon only drops the icon', () {
      final catalog = parse(
        _catalog([
          _entry({'icon': 'https://cdn.example.com/i.png?$longQuery'}),
        ]),
        publicOrigin,
      );
      expect(catalog.entries.single.icon, isNull);
      expect(catalog.dropped, 0);
    });
  });
}
