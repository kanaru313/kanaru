import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/custom_font_providers.dart';
import 'package:kanaru/core/fonts/custom_font_service.dart';
import 'package:kanaru/core/fonts/dynamic_font_loader.dart';
import 'package:kanaru/core/fonts/font_catalog_manifest.dart';
import 'package:kanaru/core/fonts/font_download_notifier.dart';
import 'package:kanaru/core/fonts/font_providers.dart';
import 'package:kanaru/core/fonts/font_storage_service.dart';
import 'package:kanaru/core/fonts/installed_catalog_fonts_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_fonts_page.dart';
import 'package:kanaru/features/settings/font_catalog_tile.dart';
import 'package:kanaru/features/settings/setting_card.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

class _FakeDynamicFontLoader extends DynamicFontLoader {
  final List<String> loadedFonts = [];
  bool shouldThrow = false;

  @override
  Future<void> loadAllCustomFonts(FontStorageService storage) async {}

  @override
  Future<void> ensureLoaded(String fontId, FontStorageService storage) async {
    if (shouldThrow) {
      throw StateError('Simulated font load failure');
    }
    loadedFonts.add(fontId);
  }
}

class _TestInstalledCatalogFontsNotifier extends InstalledCatalogFontsNotifier {
  _TestInstalledCatalogFontsNotifier(this._initial);
  final Set<String> _initial;
  final List<String> deleted = [];
  bool shouldThrowOnDelete = false;

  @override
  Set<String> build() => _initial;

  @override
  Future<void> deleteCatalogFont(String fontId) async {
    if (shouldThrowOnDelete) {
      throw const FileSystemException('Delete error');
    }
    deleted.add(fontId);
    state = {...state}..remove(fontId);
  }
}

class _TestCustomFontsNotifier extends CustomFontsNotifier {
  _TestCustomFontsNotifier(this._initial);
  final List<CustomFontItem> _initial;
  final List<String> deleted = [];
  bool importCalled = false;
  CustomFontItem? toImport;
  bool shouldThrowOnImport = false;
  bool shouldThrowOnDelete = false;

  @override
  List<CustomFontItem> build() => _initial;

  @override
  Future<CustomFontItem?> importFromPicker() async {
    importCalled = true;
    if (shouldThrowOnImport) {
      throw Exception('Import error');
    }
    if (toImport != null) {
      state = [...state, toImport!];
    }
    return toImport;
  }

  @override
  Future<void> deleteFont(String fontId) async {
    if (shouldThrowOnDelete) {
      throw const FileSystemException('Delete error');
    }
    deleted.add(fontId);
    state = state.where((f) => f.id != fontId).toList();
  }
}

class _TestFontDownloadNotifier extends FontDownloadNotifier {
  final List<String> downloaded = [];
  bool shouldThrow = false;

  @override
  Future<void> downloadFont(CatalogFontItem font) async {
    if (shouldThrow) {
      throw StateError('Download error');
    }
    downloaded.add(font.id);
  }
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  String? fontId,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  if (fontId != null) {
    final s = container.read(settingsProvider);
    container
        .read(settingsProvider.notifier)
        .setDisplay(s.display.copyWith(fontId: fontId));
  }
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const Scaffold(body: AppearanceFontsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('AppearanceFontsPage', () {
    testWidgets('renders page title, subtitle, and import button in header', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(find.text('Fonts'), findsOneWidget);
      expect(
        find.text('System font is used for CJK characters and emoji.'),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });

    testWidgets('renders 3 font groups: built-in, custom, and catalog', (
      tester,
    ) async {
      final customItem = CustomFontItem(
        id: 'custom_fira_sans',
        label: 'My Custom Fira',
        file: File('/tmp/fira.ttf'),
      );

      await _pumpPage(
        tester,
        overrides: [
          customFontsProvider.overrideWith(
            () => _TestCustomFontsNotifier([customItem]),
          ),
          installedCatalogFontsProvider.overrideWith(
            () => _TestInstalledCatalogFontsNotifier({'roboto'}),
          ),
        ],
      );

      // Group headers and card wrappers
      expect(find.byType(SettingsSection), findsNWidgets(3));
      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.byType(SettingCard), findsWidgets);

      // Group 1: Built-in fonts
      expect(
        find.descendant(
          of: find.byType(FontCatalogTile),
          matching: find.text('System'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('nunito')),
        findsOneWidget,
      );

      // Group 2: Custom fonts
      expect(
        find.descendant(
          of: find.byType(FontCatalogTile),
          matching: find.text('My Custom Fira'),
        ),
        findsOneWidget,
      );

      // Group 3: Catalog fonts
      for (final font in catalogFontsManifest) {
        expect(find.byKey(ValueKey(font.id)), findsOneWidget);
      }
    });

    testWidgets('renders 2 font groups when no custom fonts imported', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        overrides: [
          customFontsProvider.overrideWith(
            () => _TestCustomFontsNotifier([]),
          ),
        ],
      );

      expect(find.byType(SettingsSection), findsNWidgets(2));
      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Custom'), findsNothing);
    });

    testWidgets('selecting an installed font updates settings after ensureLoaded', (
      tester,
    ) async {
      final fakeLoader = _FakeDynamicFontLoader();
      final container = await _pumpPage(
        tester,
        overrides: [
          dynamicFontLoaderProvider.overrideWithValue(fakeLoader),
          installedCatalogFontsProvider.overrideWith(
            () => _TestInstalledCatalogFontsNotifier({'roboto'}),
          ),
        ],
      );

      // Tap on installed catalog font 'roboto'
      await tester.tap(find.byKey(const ValueKey('roboto')));
      await tester.pumpAndSettle();

      expect(fakeLoader.loadedFonts, contains('roboto'));
      expect(container.read(settingsProvider).display.fontId, 'roboto');
    });

    testWidgets('tapping import button opens disclaimer and triggers import', (
      tester,
    ) async {
      final customNotifier = _TestCustomFontsNotifier([]);
      customNotifier.toImport = CustomFontItem(
        id: 'custom_test',
        label: 'Imported Test Font',
        file: File('/tmp/test.ttf'),
      );

      await _pumpPage(
        tester,
        overrides: [
          customFontsProvider.overrideWith(() => customNotifier),
        ],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pumpAndSettle();

      // Disclaimer dialog is visible
      expect(find.text('Import Custom Font'), findsOneWidget);

      // Confirm disclaimer
      await tester.tap(find.text('I Understand & Import'));
      await tester.pumpAndSettle();

      expect(customNotifier.importCalled, isTrue);
      // New font appears in the list
      expect(find.text('Imported Test Font'), findsOneWidget);
    });

    testWidgets('downloading a catalog font calls downloadFont on notifier', (
      tester,
    ) async {
      final downloadNotifier = _TestFontDownloadNotifier();

      await _pumpPage(
        tester,
        overrides: [
          fontDownloadNotifierProvider.overrideWith(() => downloadNotifier),
          installedCatalogFontsProvider.overrideWith(
            () => _TestInstalledCatalogFontsNotifier({}),
          ),
        ],
      );

      final robotoTile = find.byKey(const ValueKey('roboto'));
      final downloadBtn = find.descendant(
        of: robotoTile,
        matching: find.byIcon(AppIcons.arrowDownload),
      );
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      expect(downloadNotifier.downloaded, contains('roboto'));
    });

    testWidgets('can delete installed catalog font when not active', (
      tester,
    ) async {
      final catalogNotifier = _TestInstalledCatalogFontsNotifier({'roboto', 'lora'});

      await _pumpPage(
        tester,
        fontId: 'nunito', // active font is nunito
        overrides: [
          installedCatalogFontsProvider.overrideWith(() => catalogNotifier),
        ],
      );

      final robotoTile = find.byKey(const ValueKey('roboto'));
      final deleteBtn = find.descendant(
        of: robotoTile,
        matching: find.byIcon(AppIcons.deleteOutline),
      );
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(catalogNotifier.deleted, contains('roboto'));
    });

    testWidgets('active font does not show delete button', (tester) async {
      final catalogNotifier = _TestInstalledCatalogFontsNotifier({'roboto'});

      await _pumpPage(
        tester,
        fontId: 'roboto', // roboto is active
        overrides: [
          installedCatalogFontsProvider.overrideWith(() => catalogNotifier),
        ],
      );

      final robotoTile = find.byKey(const ValueKey('roboto'));
      final deleteBtn = find.descendant(
        of: robotoTile,
        matching: find.byIcon(AppIcons.deleteOutline),
      );
      expect(deleteBtn, findsNothing);
    });

    testWidgets('installed catalog fonts are sorted to the top of catalog section', (
      tester,
    ) async {
      final catalogNotifier = _TestInstalledCatalogFontsNotifier({'roboto', 'lora'});

      await _pumpPage(
        tester,
        fontId: 'nunito',
        overrides: [
          installedCatalogFontsProvider.overrideWith(() => catalogNotifier),
        ],
      );

      final catalogTiles = tester
          .widgetList<FontCatalogTile>(find.byType(FontCatalogTile))
          .where((tile) => catalogFontsManifest.any((m) => m.id == tile.id))
          .toList();

      expect(catalogTiles.length, catalogFontsManifest.length);
      expect(catalogTiles[0].id, 'roboto');
      expect(catalogTiles[1].id, 'lora');
      expect(catalogTiles[0].isInstalled, isTrue);
      expect(catalogTiles[1].isInstalled, isTrue);
      for (var i = 2; i < catalogTiles.length; i++) {
        expect(catalogTiles[i].isInstalled, isFalse);
      }
    });

    testWidgets('deleting custom font asks for confirmation before deleting', (
      tester,
    ) async {
      final customItem = CustomFontItem(
        id: 'custom_1',
        label: 'My Custom Font',
        file: File('/tmp/custom.ttf'),
      );
      final customNotifier = _TestCustomFontsNotifier([customItem]);

      await _pumpPage(
        tester,
        fontId: 'nunito',
        overrides: [
          customFontsProvider.overrideWith(() => customNotifier),
        ],
      );

      final customTile = find.byKey(const ValueKey('custom_1'));
      final deleteBtn = find.descendant(
        of: customTile,
        matching: find.byIcon(AppIcons.deleteOutline),
      );
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Delete font?'), findsOneWidget);
      expect(
        find.text(
          '"My Custom Font" will be removed from Kanaru. The original file on your device is not affected.',
        ),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(customNotifier.deleted, contains('custom_1'));
      expect(find.byKey(const ValueKey('custom_1')), findsNothing);
    });

    testWidgets('shows error snackbar when font selection fails and keeps old font', (
      tester,
    ) async {
      final fakeLoader = _FakeDynamicFontLoader()..shouldThrow = true;

      final container = await _pumpPage(
        tester,
        fontId: 'nunito',
        overrides: [
          dynamicFontLoaderProvider.overrideWithValue(fakeLoader),
          installedCatalogFontsProvider.overrideWith(
            () => _TestInstalledCatalogFontsNotifier({'roboto'}),
          ),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('roboto')));
      await tester.pumpAndSettle();

      expect(find.text('Could not load Roboto'), findsOneWidget);
      expect(container.read(settingsProvider).display.fontId, 'nunito');
    });

    testWidgets('shows error snackbar when font download fails', (
      tester,
    ) async {
      final downloadNotifier = _TestFontDownloadNotifier()..shouldThrow = true;

      await _pumpPage(
        tester,
        overrides: [
          fontDownloadNotifierProvider.overrideWith(() => downloadNotifier),
          installedCatalogFontsProvider.overrideWith(
            () => _TestInstalledCatalogFontsNotifier({}),
          ),
        ],
      );

      final robotoTile = find.byKey(const ValueKey('roboto'));
      final downloadBtn = find.descendant(
        of: robotoTile,
        matching: find.byIcon(AppIcons.arrowDownload),
      );
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      expect(find.text('Failed to download Roboto'), findsOneWidget);
    });

    testWidgets('shows error snackbar when catalog font deletion fails', (
      tester,
    ) async {
      final catalogNotifier =
          _TestInstalledCatalogFontsNotifier({'roboto'})..shouldThrowOnDelete = true;

      await _pumpPage(
        tester,
        fontId: 'nunito',
        overrides: [
          installedCatalogFontsProvider.overrideWith(() => catalogNotifier),
        ],
      );

      final robotoTile = find.byKey(const ValueKey('roboto'));
      final deleteBtn = find.descendant(
        of: robotoTile,
        matching: find.byIcon(AppIcons.deleteOutline),
      );
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Could not load roboto'), findsOneWidget);
    });

    testWidgets('shows error snackbar when custom font deletion fails', (
      tester,
    ) async {
      final customItem = CustomFontItem(
        id: 'custom_1',
        label: 'My Custom Font',
        file: File('/tmp/custom.ttf'),
      );
      final customNotifier =
          _TestCustomFontsNotifier([customItem])..shouldThrowOnDelete = true;

      await _pumpPage(
        tester,
        fontId: 'nunito',
        overrides: [
          customFontsProvider.overrideWith(() => customNotifier),
        ],
      );

      final customTile = find.byKey(const ValueKey('custom_1'));
      final deleteBtn = find.descendant(
        of: customTile,
        matching: find.byIcon(AppIcons.deleteOutline),
      );
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load My Custom Font'), findsOneWidget);
    });

    testWidgets('shows error snackbar when font import fails', (tester) async {
      final customNotifier = _TestCustomFontsNotifier([])..shouldThrowOnImport = true;

      await _pumpPage(
        tester,
        overrides: [
          customFontsProvider.overrideWith(() => customNotifier),
        ],
      );

      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pumpAndSettle();

      // Confirm disclaimer
      await tester.tap(find.text('I Understand & Import'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Failed to import font file. Verify that the file is a valid TrueType or OpenType font.',
        ),
        findsOneWidget,
      );
    });
  });
}
