import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/library/folders/folder_art.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/placeholder_colors.dart';
import 'package:material_ui/material_ui.dart';

final _keyA = 'ab/ab${'0' * 62}.jpg';
final _keyB = 'cd/cd${'1' * 62}.jpg';

/// A music folder `/m` with two songs in `/m/x` (cover [direct]) and a
/// subfolder `/m/x/y` with more songs (cover [below]).
FolderNode _folder({String? direct, String? below, String root = '/m'}) {
  final tree = buildFolderTree(
    [root],
    [
      (dir: '$root/x', count: 2, cover: direct),
      (dir: '$root/x/y', count: 5, cover: below),
    ],
  );
  return tree.roots.single.children.single;
}

Future<void> _pump(
  WidgetTester tester,
  FolderNode folder, {
  double size = 120,
  bool direct = false,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [coverCacheDirectoryProvider.overrideWithValue('/covers')],
    child: MaterialApp(
      home: Center(
        child: FolderArt(folder: folder, size: size, direct: direct),
      ),
    ),
  ),
);

CoverArt _cover(WidgetTester tester) =>
    tester.widget<CoverArt>(find.byType(CoverArt));

void main() {
  setUp(() => PaintingBinding.instance.imageCache.clear());

  testWidgets('shows the tree cover from the cache folder', (tester) async {
    await _pump(tester, _folder(direct: _keyA, below: _keyB));
    expect(_cover(tester).path, '/covers/$_keyA');
  });

  testWidgets('direct uses the folder own cover', (tester) async {
    final other = _folder(direct: null, below: _keyB);
    await _pump(tester, other);
    expect(_cover(tester).path, '/covers/$_keyB');
    await _pump(tester, other, direct: true);
    expect(other.directCoverKey, isNull);
    expect(_cover(tester).path, isNull);
  });

  testWidgets('no cover shows the seeded placeholder with a note', (
    tester,
  ) async {
    final folder = _folder();
    await _pump(tester, folder);
    final scheme = Theme.of(tester.element(find.byType(FolderArt))).colorScheme;
    expect(_cover(tester).path, isNull);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(CoverArt),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, placeholderColors(scheme, folder.path).$1);
    expect(find.byIcon(AppIcons.musicNoteOutlined), findsOneWidget);
  });

  testWidgets('a malformed key shows the placeholder', (tester) async {
    await _pump(tester, _folder(direct: '../etc/passwd'));
    expect(_cover(tester).path, isNull);
    expect(find.byIcon(AppIcons.musicNoteOutlined), findsOneWidget);
  });

  testWidgets('the cover slot has a border, also on the pair-0 color', (
    tester,
  ) async {
    // Find a root whose placeholder is primaryContainer (pair 0).
    final scheme = ThemeData().colorScheme;
    FolderNode? pair0;
    for (var i = 0; i < 50 && pair0 == null; i++) {
      final f = _folder(root: '/m$i');
      if (placeholderColors(scheme, f.path).$1 == scheme.primaryContainer) {
        pair0 = f;
      }
    }
    expect(pair0, isNotNull);
    await _pump(tester, pair0!);
    final slot = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(CoverArt),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = slot.decoration as BoxDecoration;
    final theme = Theme.of(tester.element(find.byType(FolderArt)));
    expect(
      decoration.border,
      Border.all(color: theme.colorScheme.outlineVariant),
    );
    expect(slot.position, DecorationPosition.foreground);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(CoverArt),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, placeholderColors(theme.colorScheme, pair0.path).$1);
    expect(box.color, theme.colorScheme.primaryContainer);
  });

  testWidgets('a valid key whose file is missing shows the placeholder', (
    tester,
  ) async {
    await _pump(tester, _folder(direct: _keyA));
    expect(_cover(tester).path, '/covers/$_keyA');
    // The file read fails on the real event loop, not the test clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byIcon(AppIcons.musicNoteOutlined), findsOneWidget);
  });

  testWidgets('the art is excluded from semantics', (tester) async {
    await _pump(tester, _folder());
    expect(
      find.ancestor(
        of: find.byType(CoverArt),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });

  testWidgets('a list row has a chevron and survives large text', (
    tester,
  ) async {
    final folder = _folder(direct: _keyA);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coverCacheDirectoryProvider.overrideWithValue('/covers')],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: FolderListTile(
              folder: folder,
              title: 'A long folder name for large text',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    expect(find.byType(FolderArt), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [48.0, 200.0]) {
    testWidgets('renders at $size px without overflow', (tester) async {
      await _pump(tester, _folder(direct: _keyA), size: size);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(FolderArt),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      expect(tester.getSize(find.byType(FolderArt)), Size.square(size));
    });
  }
}
