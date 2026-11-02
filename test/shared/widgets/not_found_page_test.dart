import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/not_found_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Widget? action}) => tester.pumpWidget(
    MaterialApp(
      home: NotFoundPage(
        pageTitle: 'Artists',
        icon: AppIcons.artistOutline,
        title: 'Artist not found',
        message: 'It has no songs left.',
        action: action,
      ),
    ),
  );

  testWidgets('shows page title, icon, title and message', (tester) async {
    await pump(tester);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.byIcon(AppIcons.artistOutline), findsOneWidget);
    expect(find.text('Artist not found'), findsOneWidget);
    expect(find.text('It has no songs left.'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shows the action when given', (tester) async {
    await pump(
      tester,
      action: TextButton(onPressed: () {}, child: const Text('Back')),
    );
    expect(find.text('Back'), findsOneWidget);
  });
}
