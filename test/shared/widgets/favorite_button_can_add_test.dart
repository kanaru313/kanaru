import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required bool canAdd,
    required Set<String> favorites,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        favoritePathsProvider.overrideWith((ref) => Stream.value(favorites)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FavoriteButton(path: '/outside/a.flac', canAdd: canAdd),
        ),
      ),
    ),
  );

  VoidCallback? onPressed(WidgetTester tester) =>
      tester.widget<IconButton>(find.byType(IconButton)).onPressed;

  testWidgets('canAdd false disables the heart of a song that is no favorite', (
    tester,
  ) async {
    await pump(tester, canAdd: false, favorites: const {});
    await tester.pump();

    expect(onPressed(tester), isNull);
  });

  testWidgets('canAdd false still lets a favorite be taken out', (
    tester,
  ) async {
    await pump(tester, canAdd: false, favorites: const {'/outside/a.flac'});
    await tester.pump();

    expect(onPressed(tester), isNotNull);
  });

  testWidgets('canAdd true keeps the heart enabled', (tester) async {
    await pump(tester, canAdd: true, favorites: const {});
    await tester.pump();

    expect(onPressed(tester), isNotNull);
  });
}
