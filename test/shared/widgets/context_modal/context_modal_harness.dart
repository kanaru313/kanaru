import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps an app with a button that opens a modal whose root page shows
/// [rootActions] and whose "sub" action pushes a second page.
Future<void> pumpModalApp(
  WidgetTester tester, {
  Size size = const Size(1000, 800),
  bool disableAnimations = false,
  bool viaKeyboard = false,
  List<ContextModalAction> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sub = ContextModalPage(
    key: 'sub',
    headerBuilder: (_, nav) =>
        ContextModalTopBar(title: 'Sub page', onBack: nav.pop),
    bodyBuilder: (_, nav) => contextModalSections(nav, [
      [ContextModalAction(id: 'leaf', icon: Icons.info, label: 'Leaf action')],
    ]),
  );
  final root = ContextModalPage(
    key: 'root',
    bodyBuilder: (_, nav) => contextModalSections(nav, [
      [
        ContextModalAction(
          id: 'sub',
          icon: Icons.info,
          label: 'Open sub',
          opensPage: true,
          onTap: (nav) => nav.push(sub),
        ),
        ...extra,
      ],
    ]),
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContextModal<Object>(
              context,
              root: root,
              viaKeyboard: viaKeyboard,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
