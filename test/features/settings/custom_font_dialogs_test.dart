import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/custom_font_dialogs.dart';
import 'package:kanaru/l10n/l10n.dart';

Widget _buildTestApp({required Widget Function(BuildContext) builder}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Builder(builder: builder),
    ),
  );
}

void main() {
  group('confirmCustomFontDisclaimer', () {
    testWidgets('returns true when user confirms disclaimer', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestApp(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmCustomFontDisclaimer(context);
            },
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Import Custom Font'), findsOneWidget);
      expect(
        find.textContaining('You are importing a font file from your device'),
        findsOneWidget,
      );

      await tester.tap(find.text('I Understand & Import'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Import Custom Font'), findsNothing);
    });

    testWidgets('returns false when user cancels disclaimer', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestApp(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmCustomFontDisclaimer(context);
            },
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Import Custom Font'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Import Custom Font'), findsNothing);
    });
  });

  group('confirmDeleteCustomFont', () {
    testWidgets('shows font name and returns true when user confirms delete', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestApp(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmDeleteCustomFont(context, 'Awesome Font');
            },
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete font?'), findsOneWidget);
      expect(
        find.textContaining('"Awesome Font" will be removed from Kanaru'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Delete font?'), findsNothing);
    });

    testWidgets('returns false when user cancels delete', (tester) async {
      bool? result;

      await tester.pumpWidget(
        _buildTestApp(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmDeleteCustomFont(context, 'Awesome Font');
            },
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete font?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Delete font?'), findsNothing);
    });
  });
}
