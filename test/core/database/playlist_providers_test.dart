import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

void main() {
  test('is empty without a library', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(playlistSummariesProvider, (_, _) {});

    expect(await container.read(playlistSummariesProvider.future), isEmpty);
  });

  test('lists the playlists of the open library, newest first', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createPlaylist('Old', now: 1);
    await db.createPlaylist('New', now: 2);
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(playlistSummariesProvider, (_, _) {});

    final list = await container.read(playlistSummariesProvider.future);

    expect(list.map((p) => p.name), ['New', 'Old']);
  });

  test('favorites are empty and absent without a library', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(favoritePathsProvider, (_, _) {});
    container.listen(favoritesPlaylistIdProvider, (_, _) {});

    expect(await container.read(favoritePathsProvider.future), isEmpty);
    expect(await container.read(favoritesPlaylistIdProvider.future), isNull);
  });

  test('favorites follow the open library', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setFavorite('/m/a', favorite: true, now: 1);
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(favoritePathsProvider, (_, _) {});
    container.listen(favoritesPlaylistIdProvider, (_, _) {});

    expect(await container.read(favoritePathsProvider.future), {'/m/a'});
    expect(
      await container.read(favoritesPlaylistIdProvider.future),
      await db.favoritesPlaylistId(),
    );
  });
}
