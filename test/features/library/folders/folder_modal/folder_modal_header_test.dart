import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_art.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_data.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_header.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_links.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'folder_modal_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  FolderNode? folder,
  FolderStats? stats,
  bool direct = false,
  bool showFolder = true,
  VoidCallback? onTap,
}) {
  final node = folder ?? testFolder;
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FolderModalHeader(
            folder: node,
            data: FolderModalData(
              folder: node,
              direct: direct,
              showFolder: showFolder,
              stats: stats,
            ),
            direct: direct,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders 64 px FolderArt, title and stats without duration before loaded',
    (tester) async {
      await _pump(tester);
      expect(tester.getSize(find.byType(FolderArt)), const Size(64, 64));
      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('3 songs • 2 subfolders'), findsOneWidget);
    },
  );

  testWidgets('renders duration once stats are loaded', (tester) async {
    await _pump(tester, stats: testStats);
    expect(find.text('3 songs • 2 subfolders • 10 min'), findsOneWidget);
  });

  testWidgets('direct mode counts direct songs and omits subfolders', (
    tester,
  ) async {
    await _pump(
      tester,
      direct: true,
      stats: const (durationMs: 180000, songCount: 1, samplePath: null),
    );
    expect(find.text('1 song • 3 min'), findsOneWidget);
  });

  testWidgets('singular subfolder displays 1 subfolder', (tester) async {
    final folder = makeFolderNode(subfolders: 1, songs: 2);
    await _pump(tester, folder: folder);
    expect(find.text('2 songs • 1 subfolder'), findsOneWidget);
  });

  testWidgets('a tap on the header calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tap(find.text('Rock'));
    await tester.tap(find.byType(FolderArt));
    expect(taps, 2);
  });

  testWidgets('tappable header is a button with no keyboard focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, onTap: () {});
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Rock'), matching: find.byType(InkWell)),
    );
    expect(ink.canRequestFocus, isFalse);
    final data = tester
        .getSemantics(
          find.ancestor(of: find.text('Rock'), matching: find.byType(InkWell)),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hint, 'Go to folder');
    handle.dispose();
  });

  testWidgets('without onTap the header is not tappable', (tester) async {
    await _pump(tester);
    expect(
      find.ancestor(of: find.text('Rock'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('in modal a tap on the header navigates to the folder', (
    tester,
  ) async {
    final host = await pumpFolderHost(tester);
    await openFolderModalOf(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FolderModalHeader),
        matching: find.text('Rock'),
      ),
    );
    await settleModal(tester);
    expect(find.byType(FolderModalHeader), findsNothing);
    expect(host.location, folderLocation(testFolder.path));
  });

  testWidgets('on folder own page the header in modal is not tappable', (
    tester,
  ) async {
    await pumpFolderHost(tester, showFolder: false);
    await openFolderModalOf(tester);
    final header = find.byType(FolderModalHeader);
    expect(header, findsOneWidget);
    expect(
      find.ancestor(
        of: find.descendant(of: header, matching: find.text('Rock')),
        matching: find.descendant(of: header, matching: find.byType(InkWell)),
      ),
      findsNothing,
    );
  });
}
