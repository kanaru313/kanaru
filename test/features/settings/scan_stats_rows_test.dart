import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/scan_stats_queries.dart';
import 'package:kanaru/core/indexer/scan_stats.dart';
import 'package:kanaru/features/settings/scan_stats_provider.dart';
import 'package:kanaru/features/settings/scan_stats_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pump(
  WidgetTester tester, {
  required Stream<ScanDbStats?> db,
  ScanStats? session,
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanDbStatsProvider.overrideWith((ref) => db),
        if (session != null)
          lastScanStatsProvider.overrideWith(() => _Fixed(session)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The Material delegates here have no Vietnamese; only the app's
        // strings are switched.
        home: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: Locale(locale),
            delegates: AppLocalizations.localizationsDelegates,
            child: const Scaffold(
              body: SingleChildScrollView(child: ScanStatsRows()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Fixed extends LastScanStats {
  _Fixed(this.value);
  final ScanStats value;
  @override
  ScanStats? build() => value;
}

const ScanDbStats _db = (
  tracks: 1234,
  tagErrors: 2,
  withCover: 1000,
  covers: 321,
);

void main() {
  testWidgets('shows the scan numbers of the session and the database', (
    tester,
  ) async {
    await pump(
      tester,
      db: Stream.value(_db),
      session: const ScanStats(
        seen: 1500,
        nomedia: 10,
        excluded: 20,
        tooSmall: 30,
        tooShort: 40,
      ),
    );

    expect(find.text('1,234 of 1,500 music files'), findsOneWidget);
    expect(
      find.text(
        '.nomedia folders: 10 · Left-out folders: 20 · '
        'Under minimum size: 30 · Under minimum length: 40',
      ),
      findsOneWidget,
    );
    expect(find.text('2 songs stored without readable tags'), findsOneWidget);
    expect(
      find.text('321 images made for 1,000 songs with art'),
      findsOneWidget,
    );
    expect(
      find.text('An image repeated in many songs is stored once (by hash).'),
      findsOneWidget,
    );
    expect(find.textContaining('Not scanned'), findsNothing);
  });

  testWidgets('says so when no scan ended in this session', (tester) async {
    await pump(tester, db: Stream.value(_db));

    expect(
      find.text('1,234 tracks · Not scanned in this session'),
      findsOneWidget,
    );
    expect(find.text('Not scanned in this session'), findsOneWidget);
    expect(find.text('2 songs stored without readable tags'), findsOneWidget);
  });

  testWidgets('speaks Vietnamese', (tester) async {
    await pump(
      tester,
      db: Stream.value(_db),
      session: const ScanStats(seen: 1500),
      locale: 'vi',
    );

    expect(find.text('Bài lấy được'), findsOneWidget);
    expect(find.text('1.234 trên 1.500 file nhạc'), findsOneWidget);
    expect(find.text('2 bài lưu không đọc được tag'), findsOneWidget);
    expect(find.text('Ảnh trùng chỉ lưu một lần (theo hash).'), findsOneWidget);
  });

  testWidgets('is hidden without a library', (tester) async {
    await pump(tester, db: Stream.value(null));

    expect(find.text('Songs found'), findsNothing);
  });

  testWidgets('shows dots while loading and dashes when the count fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanDbStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('no count')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ScanStatsRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Songs found'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
  });
}
