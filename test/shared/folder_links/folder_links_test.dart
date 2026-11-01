import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/folder_links/folder_link_row.dart';
import 'package:kanaru/shared/folder_links/folder_links_page.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:material_ui/material_ui.dart';

final _l10n = AppLocalizationsEn();

const _rock = AlbumFolder(
  path: '/music/Rock',
  songCount: 3,
  samplePath: '/music/Rock/a.flac',
);
const _jazz = AlbumFolder(
  path: '/music/Jazz',
  songCount: 2,
  samplePath: '/music/Jazz/b.flac',
);

ContextModalAction? _row(List<AlbumFolder>? folders) => folderLinkRow(
  _l10n,
  folders,
  goToFolder: (_) {},
  showInFileManager: (_) {},
  openFolders: (_) {},
);

void main() {
  test('row is greyed out while the folders load', () {
    final row = _row(null)!;
    expect(row.enabled, isFalse);
    expect(row.onTap, isNull);
  });

  test('no row without a local folder', () {
    expect(_row(const []), isNull);
  });

  test('one folder shows its name and runs both buttons', () {
    final calls = <String>[];
    final row = folderLinkRow(
      _l10n,
      const [_rock],
      goToFolder: calls.add,
      showInFileManager: (p) => calls.add('fm:$p'),
      openFolders: null,
    )!;
    expect(row.id, 'folder');
    expect(row.subtitle, 'Rock');
    expect(row.opensPage, isFalse);
    expect(row.trailing, hasLength(1));
    var closed = 0;
    final nav = ContextModalNav(
      push: (_) {},
      pop: () {},
      close: ([_]) => closed++,
    );
    row.onTap!(nav);
    row.trailing.single.onTap(nav);
    expect(closed, 2);
    expect(calls, ['/music/Rock', 'fm:/music/Rock/a.flac']);
  });

  test('several folders open a page with the total song count', () {
    final row = _row(const [_rock, _jazz])!;
    expect(row.id, 'folders');
    expect(row.opensPage, isTrue);
    expect(row.subtitle, _l10n.albumModalSongsInFolders(5, 2));
  });

  testWidgets('page lists a row per folder and runs the callbacks', (
    tester,
  ) async {
    final went = <String>[];
    final shown = <String>[];
    final page = folderLinksPage(
      key: 'folders',
      title: (l10n) => 'Folders of X',
      intro: (l10n) => l10n.albumModalFoldersIntro(2),
      folders: const [_rock, _jazz],
      goToFolder: went.add,
      showInFileManager: shown.add,
      keepAlive: (bar) => Column(children: [bar, const Text('kept')]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showContextModal<Object>(context, root: page),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Folders of X'), findsOneWidget);
    expect(find.text('kept'), findsOneWidget);
    expect(find.text(_l10n.albumModalFoldersIntro(2)), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);

    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();
    expect(went, ['/music/Jazz']);
    expect(shown, isEmpty);

    // Every action closes the modal; open it again for the other button.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_l10n.libraryShowInFileManager).first);
    await tester.pumpAndSettle();
    expect(shown, ['/music/Rock/a.flac']);
    expect(went, ['/music/Jazz']);
  });
}
