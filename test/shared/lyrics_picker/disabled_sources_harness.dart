import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// A source with its own name, host and one answer (or none).
class NamedSource extends FakeLyricsProvider {
  NamedSource(String id, this._name, this._host, {String? title})
    : super(id: id) {
    if (title != null) {
      searchResult = [
        fakeCandidate(
          providerId: id,
          remoteId: id,
          title: title,
          body: LyricsBody(syncedLrc: '[00:01.00] $title words'),
        ),
      ];
    }
  }

  final String _name;
  final String _host;

  /// The text of each search this source answered.
  final searchedTexts = <String>[];

  @override
  Future<List<LyricsCandidate>> search(LyricsQuery query, LyricsHttp http) {
    searchedTexts.add(query.text ?? '');
    return super.search(query, http);
  }

  @override
  String get displayName => _name;

  @override
  List<String> get hosts => [_host];
}

Future<void> settleUi(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
}

/// Opens the Choose lyrics dialog over [on] (enabled) and [off] (disabled)
/// sources; returns the harness.
Future<LyricsHarness> openPickerWith(
  WidgetTester tester, {
  List<FakeLyricsProvider> on = const [],
  List<FakeLyricsProvider> off = const [],
  LyricsTarget? target,
}) async {
  tester.view
    ..physicalSize = const Size(1280, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await createHarness(
    [for (final p in on) LyricsProviderRegistration(p)],
    overrides: [
      // Off sources are named by their plugin records in the app.
      lyricsSourceNamesProvider.overrideWithValue({
        for (final p in [...on, ...off])
          p.id: LyricsSourceName(displayName: p.displayName),
      }),
      disabledLyricsProvidersProvider.overrideWithValue([
        for (final p in off) LyricsProviderRegistration(p),
      ]),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLyricsPicker(
              navigator: Navigator.of(context),
              container: h.container,
              target: target ?? fakeTarget,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await settleUi(tester);
  return h;
}

/// A row of the Search sources modal (result tiles have no trailing).
Finder sourceRow(String title) => find.byWidgetPredicate(
  (w) => w is SelectionRow && w.title == title && w.trailing != null,
);
