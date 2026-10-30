import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_url.dart';

void main() {
  group('normalizeRepoUrl', () {
    test(
      'lower-cases, drops default ports and fragments, keeps the path as typed',
      () {
        expect(
          normalizeRepoUrl('HTTPS://Repo.Example.COM:443/A/b/'),
          'https://repo.example.com/A/b/',
        );
        expect(
          normalizeRepoUrl('http://repo.lan:80/x.json#top'),
          'http://repo.lan/x.json',
        );
        expect(
          normalizeRepoUrl('http://repo.lan:8080/x.json'),
          'http://repo.lan:8080/x.json',
        );
        // Only a bare root slash goes: the request for it is the same.
        expect(
          normalizeRepoUrl('  https://repo.example.com/  '),
          'https://repo.example.com',
        );
        expect(
          normalizeRepoUrl('https://repo.example.com/catalog/'),
          'https://repo.example.com/catalog/',
        );
        expect(
          normalizeRepoUrl('https://repo.example.com/?v=1'),
          'https://repo.example.com?v=1',
        );
        expect(normalizeRepoUrl('http://[::1]:8080/p'), 'http://[::1]:8080/p');
      },
    );

    test('spellings of one repo are equal', () {
      expect(
        normalizeRepoUrl('https://a.example.com/p#x'),
        normalizeRepoUrl('HTTPS://A.EXAMPLE.COM:443/p'),
      );
    });

    test('rejects what is not an http(s) address with a host', () {
      for (final bad in [
        '',
        'x',
        'ftp://a.example.com',
        'https://',
        '/p',
        'file:///etc',
      ]) {
        expect(normalizeRepoUrl(bad), isNull, reason: bad);
      }
    });
  });

  group('stored catalog', () {
    final catalog = PluginCatalog(
      name: 'Repo',
      author: 'me',
      dropped: 3,
      entries: [
        PluginCatalogEntry(
          slug: 'a',
          name: 'A',
          version: 2,
          apiVersion: 1,
          hosts: const ['h.example.com'],
          path: Uri.parse('https://r.example.com/a.zip'),
          icon: Uri.parse('https://r.example.com/a.png'),
          description: 'line\ntwo',
          author: 'x',
        ),
        PluginCatalogEntry(
          slug: 'b',
          name: 'B',
          version: 1,
          apiVersion: 2,
          hosts: const ['h.example.com'],
          path: Uri.parse('https://r.example.com/b.zip'),
        ),
      ],
    );

    test('round-trips entries and the repository class', () {
      final text = encodeStoredCatalog(catalog, RepoAddressKind.public);
      final back = decodeStoredCatalog('https://r.example.com/c.json', text)!;
      expect(back.kind, RepoAddressKind.public);
      expect(back.catalog.name, 'Repo');
      expect(back.catalog.author, 'me');
      final a = back.catalog.entries.first;
      expect(a.path, Uri.parse('https://r.example.com/a.zip'));
      expect(a.icon, Uri.parse('https://r.example.com/a.png'));
      expect(a.description, 'line\ntwo');
      expect(back.catalog.entries.last.apiVersion, 2);
      expect(back.catalog.entries.last.icon, isNull);
    });

    test('damaged or foreign text reads as nothing', () {
      for (final text in [
        'nope',
        '[]',
        jsonEncode({
          'metadata': {'name': 'x'},
          'data': [],
        }),
        jsonEncode({
          'kind': 'other',
          'metadata': {'name': 'x'},
          'data': [],
        }),
      ]) {
        expect(
          decodeStoredCatalog('https://r.example.com/c.json', text),
          isNull,
        );
      }
    });

    test('only the error kind is stored; the reason is attached on read', () {
      const refused = RepoLoadError(
        RepoFetchErrorKind.blockedAddress,
        reason: RepoAddressProblem.localFromPublic,
      );
      const network = RepoLoadError(RepoFetchErrorKind.network);
      expect(refused.encode(), 'blockedAddress');
      expect(network.encode(), 'network');
      expect(RepoLoadError.decode(network.encode()), network);
      expect(
        RepoLoadError.decode(refused.encode(), reason: refused.reason),
        refused,
      );
      // A reason only goes with a refused address.
      expect(
        RepoLoadError.decode(
          network.encode(),
          reason: RepoAddressProblem.localFromPublic,
        ),
        network,
      );
      expect(RepoLoadError.decode(null), isNull);
      expect(RepoLoadError.decode('weird'), isNull);
    });
  });
}
