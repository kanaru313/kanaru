import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: KanaruApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the library screen', (tester) async {
    await pumpApp(tester, const Size(1280, 800));

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('uses a navigation rail on wide windows', (tester) async {
    await pumpApp(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses a bottom navigation bar on narrow windows', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('switches screens from the navigation rail', (tester) async {
    await pumpApp(tester, const Size(1280, 800));

    await tester.tap(find.byIcon(Icons.queue_music_outlined));
    await tester.pumpAndSettle();

    expect(find.text('No playlists yet'), findsOneWidget);
  });
}
