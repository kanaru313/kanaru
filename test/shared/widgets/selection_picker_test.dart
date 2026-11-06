import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/selection_picker.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

List<SelectionPickerItem<String>> _makeItems(int count) => [
  for (var i = 1; i <= count; i++)
    SelectionPickerItem(
      value: 'id_$i',
      name: 'Option $i',
      description: 'Description $i',
    ),
];

const _languageItems = <SelectionPickerItem<String>>[
  SelectionPickerItem(
    value: 'vi',
    name: 'Tiếng Việt',
    description: 'Theo ngôn ngữ ứng dụng',
  ),
  SelectionPickerItem(value: 'en', name: 'English', description: 'Latin'),
  SelectionPickerItem(value: 'ja', name: 'Japanese', description: 'Kanji'),
  SelectionPickerItem(value: 'ko', name: 'Korean', description: 'Hangul'),
  SelectionPickerItem(value: 'zh-Hans', name: 'Chinese (Simplified)'),
  SelectionPickerItem(value: 'zh-Hant', name: 'Chinese (Traditional)'),
  SelectionPickerItem(value: 'fr', name: 'French'),
  SelectionPickerItem(value: 'de', name: 'German'),
  SelectionPickerItem(
    value: 'es',
    name: 'Spanish',
    description: 'Romance language',
  ),
];

Future<void> _pumpPickerHost<T>(
  WidgetTester tester, {
  required List<SelectionPickerItem<T>> items,
  required ValueChanged<T?> onResult,
  T? selected,
  String title = 'Pick item',
  Widget? footer,
  String? hint,
  Locale? locale,
}) async {
  tester.view
    ..physicalSize = const Size(1000, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showSelectionPicker<T>(
                context,
                title: title,
                items: items,
                selected: selected,
                footer: footer,
                hint: hint,
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Not pumpAndSettle: an overflowing row title (long language name) starts a
  // back-and-forth marquee that never settles once its start delay passes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Whether the picker's search box really holds the keyboard focus.
bool _searchHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  testWidgets('8 items show no search box', (tester) async {
    String? picked = 'initial';
    await _pumpPickerHost<String>(
      tester,
      items: _makeItems(8),
      onResult: (v) => picked = v,
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SelectionRow), findsNWidgets(8));
    expect(picked, 'initial');
  });

  testWidgets(
    '9 items show an autofocused search box and filter by name, description and accent-free query',
    (tester) async {
      String? picked;
      await _pumpPickerHost<String>(
        tester,
        items: _languageItems,
        selected: 'ja',
        onResult: (v) => picked = v,
      );

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      expect(find.text('Search 9 items'), findsOneWidget);
      expect(_searchHasFocus(tester), isTrue);

      // Filter by name ignoring accents and case: "viet" matches "Tiếng Việt".
      await tester.enterText(searchField, 'viet');
      await tester.pump();
      expect(find.byType(SelectionRow), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);

      // Filter by description: "romance" matches "Spanish".
      await tester.enterText(searchField, 'romance');
      await tester.pump();
      expect(find.byType(SelectionRow), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);

      // No match shows "Nothing matches …", never "No songs match …".
      await tester.enterText(searchField, 'klingon');
      await tester.pump();
      expect(find.byType(SelectionRow), findsNothing);
      expect(find.text('Nothing matches “klingon”'), findsOneWidget);
      expect(find.textContaining('No songs match'), findsNothing);
      expect(picked, isNull);
    },
  );

  testWidgets('picking a row closes the picker and returns its value', (
    tester,
  ) async {
    var completed = false;
    String? picked;
    await _pumpPickerHost<String>(
      tester,
      items: _makeItems(4),
      selected: 'id_1',
      onResult: (v) {
        completed = true;
        picked = v;
      },
    );

    await tester.tap(find.text('Option 3'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(picked, 'id_3');
    expect(find.text('Pick item'), findsNothing);
  });

  testWidgets(
    'Esc dismisses and returns null even while the search box has focus',
    (tester) async {
      var completed = false;
      String? picked = 'initial';
      await _pumpPickerHost<String>(
        tester,
        items: _languageItems,
        onResult: (v) {
          completed = true;
          picked = v;
        },
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(_searchHasFocus(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(picked, isNull);
      expect(find.text('Pick item'), findsNothing);
    },
  );

  testWidgets(
    'renders Vietnamese search hint, no-match text, footer and hint',
    (tester) async {
      await _pumpPickerHost<String>(
        tester,
        locale: const Locale('vi'),
        items: _languageItems,
        footer: const Text('Tải thêm plugin dịch'),
        hint: 'Bản dịch đã có trong máy vẫn được dùng trước.',
        onResult: (_) {},
      );

      expect(find.text('Tìm trong 9 mục'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();
      expect(find.text('Không có mục nào khớp «xyz»'), findsOneWidget);
      expect(find.text('Tải thêm plugin dịch'), findsOneWidget);
      expect(
        find.text('Bản dịch đã có trong máy vẫn được dùng trước.'),
        findsOneWidget,
      );
    },
  );
}
