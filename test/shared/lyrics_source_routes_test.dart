import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';

void main() {
  test('the fixed paths', () {
    expect(lyricsSourcesRoute, '/settings/lyrics-sources');
    expect(
      lyricsPluginRoutePattern,
      '/settings/lyrics-sources/plugin/:installId',
    );
    expect(lyricsStoreRoute, '/settings/lyrics-sources/store');
    expect(
      lyricsStoreRepositoriesRoute,
      '/settings/lyrics-sources/store/repositories',
    );
  });

  test('a plugin route holds the install id, encoded', () {
    expect(lyricsPluginRoute('abc-1'), '/settings/lyrics-sources/plugin/abc-1');
    expect(
      lyricsPluginRoute('a/b c'),
      '/settings/lyrics-sources/plugin/a%2Fb%20c',
    );
  });

  test('a store item route encodes the repository and the slug', () {
    final route = lyricsStoreItemRoute(
      repoUrl: 'https://example.org/repo?x=1&y=2',
      slug: 'my plugin',
    );
    expect(route, startsWith('/settings/lyrics-sources/store/item?'));
    final uri = Uri.parse(route);
    expect(uri.path, '/settings/lyrics-sources/store/item');
    expect(uri.queryParameters, {
      'repo': 'https://example.org/repo?x=1&y=2',
      'slug': 'my plugin',
    });
  });
}
