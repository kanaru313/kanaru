import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/font_catalog_tile.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Material(child: child),
    ),
  );
}

void main() {
  group('FontCatalogTile', () {
    testWidgets('renders SVG preview and does not render duplicate text label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'inter',
            label: 'Inter',
            previewSvgAsset: 'assets/font_previews/inter.svg',
            isSelected: false,
            isInstalled: true,
            isDownloading: false,
            onSelect: () {},
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.fit, BoxFit.scaleDown);
      expect(svg.alignment, Alignment.centerLeft);
      expect(svg.semanticsLabel, 'Inter');

      // The SVG already contains the font name, so no Text with label or sample text
      expect(find.text('Inter'), findsNothing);
      expect(find.text(fontPreviewSampleText), findsNothing);
    });

    testWidgets('renders fallback text when previewSvgAsset is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'custom_1',
            label: 'My Custom Font',
            family: 'MyCustomFontFamily',
            isSelected: false,
            isInstalled: true,
            isDownloading: false,
            onSelect: () {},
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('My Custom Font'), findsOneWidget);
      expect(find.text(fontPreviewSampleText), findsOneWidget);

      final labelText = tester.widget<Text>(find.text('My Custom Font'));
      expect(labelText.style?.fontFamily, 'MyCustomFontFamily');
    });

    testWidgets('renders fallback text without font family when uninstalled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'custom_2',
            label: 'Uninstalled Font',
            family: 'SomeFamily',
            isSelected: false,
            isInstalled: false,
            isDownloading: false,
            onSelect: () {},
          ),
        ),
      );

      final labelText = tester.widget<Text>(find.text('Uninstalled Font'));
      expect(labelText.style?.fontFamily, isNot('SomeFamily'));
    });

    testWidgets('shows checkmark when isSelected is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'inter',
            label: 'Inter',
            isSelected: true,
            isInstalled: true,
            isDownloading: false,
            onSelect: () {},
          ),
        ),
      );

      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when isDownloading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'roboto',
            label: 'Roboto',
            downloadProgress: 0.65,
            isSelected: false,
            isInstalled: false,
            isDownloading: true,
            onSelect: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.65);
    });

    testWidgets(
      'uninstalled row shows formattedSize, download button, and does not select on row tap',
      (tester) async {
        var selected = false;
        var downloaded = false;

        await tester.pumpWidget(
          _wrap(
            FontCatalogTile(
              id: 'roboto',
              label: 'Roboto',
              formattedSize: '160 KB',
              isSelected: false,
              isInstalled: false,
              isDownloading: false,
              onSelect: () => selected = true,
              onDownload: () => downloaded = true,
            ),
          ),
        );

        expect(find.text('160 KB'), findsOneWidget);
        expect(find.byIcon(AppIcons.arrowDownload), findsOneWidget);

        // Tap on the row itself
        await tester.tap(find.text('Roboto'));
        await tester.pump();
        expect(selected, isFalse, reason: 'Tapping uninstalled row must not call onSelect');
        expect(downloaded, isFalse, reason: 'Tapping row must not trigger download');

        // Tap the download icon button
        await tester.tap(find.byIcon(AppIcons.arrowDownload));
        await tester.pump();
        expect(downloaded, isTrue);
      },
    );

    testWidgets('installed row calls onSelect when tapped', (tester) async {
      var selected = false;

      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'inter',
            label: 'Inter',
            isSelected: false,
            isInstalled: true,
            isDownloading: false,
            onSelect: () => selected = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(selected, isTrue);
    });

    testWidgets('shows delete icon and calls onDelete when canDelete is true', (
      tester,
    ) async {
      var deleted = false;

      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'custom_1',
            label: 'Custom Font',
            canDelete: true,
            isSelected: false,
            isInstalled: true,
            isDownloading: false,
            onSelect: () {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      expect(find.byIcon(AppIcons.deleteOutline), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.deleteOutline));
      await tester.pump();
      expect(deleted, isTrue);
    });

    testWidgets('does not show delete icon when canDelete is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FontCatalogTile(
            id: 'custom_1',
            label: 'Custom Font',
            canDelete: false,
            isSelected: false,
            isInstalled: true,
            isDownloading: false,
            onSelect: () {},
            onDelete: () {},
          ),
        ),
      );

      expect(find.byIcon(AppIcons.deleteOutline), findsNothing);
    });
  });
}
