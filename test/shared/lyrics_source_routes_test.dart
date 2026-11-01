import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';

void main() {
  test('the fixed paths', () {
    expect(lyricsSourcesRoute, '/settings/playback/lyrics-sources');
    expect(
      lyricsPluginRoutePattern,
      '/settings/playback/lyrics-sources/plugin/:installId',
    );
    expect(lyricsStoreRoute, '/settings/plugins');
    expect(
      lyricsSourcesStoreRoute,
      '/settings/playback/lyrics-sources/plugins',
    );
    expect(
      lyricsStoreRepositoriesRoute(lyricsStoreRoute),
      '/settings/plugins/repositories',
    );
    expect(
      lyricsStoreRepositoriesRoute(lyricsSourcesStoreRoute),
      '/settings/playback/lyrics-sources/plugins/repositories',
    );
  });

  test('a plugin route holds the install id, encoded', () {
    expect(
      lyricsPluginRoute('abc-1'),
      '/settings/playback/lyrics-sources/plugin/abc-1',
    );
    expect(
      lyricsPluginRoute('a/b c'),
      '/settings/playback/lyrics-sources/plugin/a%2Fb%20c',
    );
  });

  test('a store item route encodes the repository and the slug', () {
    final route = lyricsStoreItemRoute(
      base: lyricsStoreRoute,
      repoUrl: 'https://example.org/repo?x=1&y=2',
      slug: 'my plugin',
    );
    expect(route, startsWith('/settings/plugins/item?'));
    final uri = Uri.parse(route);
    expect(uri.path, '/settings/plugins/item');
    expect(uri.queryParameters, {
      'repo': 'https://example.org/repo?x=1&y=2',
      'slug': 'my plugin',
    });
  });
}
