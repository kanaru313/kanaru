import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_coming_soon_button.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_header.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  Widget? trailing,
  Widget? below,
  bool? canRequestFocus,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ContextModalHeader(
        leading: const SizedBox(width: 64, height: 64),
        lines: [contextModalHeaderLine('Title', null)],
        trailing: trailing,
        below: below,
        onTap: onTap,
        tapHint: 'Go there',
        canRequestFocus: canRequestFocus ?? false,
      ),
    ),
  ),
);

void main() {
  testWidgets('a tap in the padding fires onTap', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    final header = find.byType(ContextModalHeader);
    await tester.tapAt(tester.getTopLeft(header) + const Offset(4, 4));
    expect(taps, 1);
  });

  testWidgets('the coming soon button keeps its own tap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      onTap: () => taps++,
      trailing: const ContextModalComingSoonIconButton(
        icon: Icons.edit,
        tooltip: 'Do it',
      ),
    );
    await tester.tap(find.byTooltip('Do it'));
    await tester.pump();
    expect(taps, 0);
    expect(find.textContaining('available yet'), findsOneWidget);
  });

  testWidgets('a plain trailing button does not fire onTap', (tester) async {
    var header = 0;
    var button = 0;
    await _pump(
      tester,
      onTap: () => header++,
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => button++,
      ),
    );
    await tester.tap(find.byType(IconButton));
    expect(button, 1);
    expect(header, 0);
  });

  testWidgets('without onTap there is no ink and no button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.ancestor(of: find.text('Title'), matching: find.byType(InkWell)),
      findsNothing,
    );
    final node = tester.getSemantics(find.text('Title'));
    expect(node.flagsCollection.isButton, isFalse);
    handle.dispose();
  });

  testWidgets('the ink fills the header, has no radius, takes no focus', (
    tester,
  ) async {
    await _pump(tester, onTap: () {});
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.borderRadius, isNull);
    expect(ink.canRequestFocus, isFalse);
    expect(
      tester.getRect(find.byType(InkWell)),
      tester.getRect(find.byType(ContextModalHeader)),
    );
  });

  testWidgets('canRequestFocus can be turned on', (tester) async {
    await _pump(tester, onTap: () {}, canRequestFocus: true);
    expect(
      tester.widget<InkWell>(find.byType(InkWell)).canRequestFocus,
      isTrue,
    );
  });

  testWidgets('header is a button with the hint; the trailing one is apart', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      onTap: () {},
      trailing: const ContextModalComingSoonIconButton(
        icon: Icons.edit,
        tooltip: 'Do it',
      ),
    );
    final head = tester.getSemantics(
      find.ancestor(of: find.text('Title'), matching: find.byType(InkWell)),
    );
    expect(head.flagsCollection.isButton, isTrue);
    expect(head.hint, 'Go there');
    expect(head.label, isNot(contains('Do it')));
    final button = tester
        .getSemantics(find.byTooltip('Do it'))
        .getSemanticsData();
    expect(button.flagsCollection.isButton, isTrue);
    expect(button.hint, 'Coming soon');
    expect(
      find.ancestor(
        of: find.byTooltip('Do it'),
        matching: find.byType(ExcludeFocus),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('below sits under the row and inside the ink', (tester) async {
    await _pump(tester, onTap: () {}, below: const Text('Desc'));
    expect(
      find.ancestor(of: find.text('Desc'), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Desc')).dy,
      greaterThan(tester.getBottomLeft(find.text('Title')).dy),
    );
  });
}
