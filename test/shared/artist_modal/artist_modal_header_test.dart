import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_header.dart';
import 'package:kanaru/shared/artist_summaries.dart';
import 'package:kanaru/shared/widgets/artist_avatar.dart';
import 'package:material_ui/material_ui.dart';

import 'artist_modal_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  String name = 'Ann',
  ArtistSummary artist = testArtist,
  VoidCallback? onTap,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ArtistModalHeader(artist: artist, name: name, onTap: onTap),
      ),
    ),
  ),
);

void main() {
  testWidgets('64 px round picture, name and counts from the snapshot', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(ArtistAvatar)), const Size(64, 64));
    expect(find.text('Ann'), findsWidgets);
    expect(find.text('3 albums • 12 songs • 1 h 0 min'), findsOneWidget);
  });

  testWidgets('an unknown length is left out', (tester) async {
    await _pump(
      tester,
      artist: const ArtistSummary(
        key: 'ann',
        name: 'Ann',
        songCount: 1,
        albumCount: 1,
      ),
    );
    expect(find.text('1 album • 1 song'), findsOneWidget);
  });

  testWidgets('the name switches to the loaded spelling', (tester) async {
    await _pump(tester, name: 'sơn tùng');
    expect(find.text('sơn tùng'), findsOneWidget);
    await _pump(tester, name: 'Sơn Tùng');
    expect(find.text('Sơn Tùng'), findsOneWidget);
    expect(find.text('sơn tùng'), findsNothing);
  });

  testWidgets('a tap on the picture or the text goes to the artist', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tap(find.text('Ann'));
    await tester.tap(find.byType(ArtistAvatar));
    expect(taps, 2);
  });

  testWidgets('no tap on the artist page; the text is not a button', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      find.ancestor(of: find.text('Ann'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('the tappable header takes no keyboard focus', (tester) async {
    await _pump(tester, onTap: () {});
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Ann'), matching: find.byType(InkWell)),
    );
    expect(ink.canRequestFocus, isFalse);
  });

  testWidgets('Set artist picture answers with a coming soon snackbar', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Set artist picture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("isn't available yet"), findsOneWidget);
  });

  testWidgets('Set artist picture says coming soon and takes no focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final data = tester
        .getSemantics(find.byTooltip('Set artist picture'))
        .getSemanticsData();
    expect(data.hint, 'Coming soon');
    expect(data.flagsCollection.isButton, isTrue);
    expect(
      find.ancestor(
        of: find.byTooltip('Set artist picture'),
        matching: find.byType(ExcludeFocus),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
