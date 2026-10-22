import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/favorites_screen.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Locale locale) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const FavoritesScreen(),
  ),
);

void main() {
  testWidgets('says liked songs will show up here', (tester) async {
    await _pump(tester, const Locale('en'));

    // The page title and the empty state title.
    expect(find.text('Favorites'), findsNWidgets(2));
    expect(find.text('Songs you like will show up here.'), findsOneWidget);
  });

  testWidgets('is called Yêu thích in Vietnamese', (tester) async {
    await _pump(tester, const Locale('vi'));

    expect(find.text('Yêu thích'), findsNWidgets(2));
    expect(find.text('Bài hát bạn thích sẽ hiện ở đây.'), findsOneWidget);
  });
}
