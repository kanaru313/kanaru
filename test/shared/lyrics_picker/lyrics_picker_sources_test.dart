import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_state.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_results_pane.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';

const _plugin = 'plugin-aaaaaaaaaaaa';
const _other = 'plugin-bbbbbbbbbbbb';

const _query = LyricsQuery(
  title: 'Song',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);

RankedCandidate _result(String providerId, String title) {
  final candidate = fakeCandidate(
    providerId: providerId,
    remoteId: title,
    title: title,
  );
  return RankedCandidate(candidate, matchCandidate(_query, candidate));
}

/// Hosts a pane over [state] filtered to [filter].
class _Host extends StatefulWidget {
  const _Host({
    required this.state,
    required this.names,
    this.onSelect,
    this.filter,
  });

  final LyricsSearchState state;
  final Map<String, String> names;
  final ValueChanged<int>? onSelect;
  final String? filter;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int retries = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('retries $retries'),
      Expanded(
        child: LyricsPickerResultsPane(
          state: widget.state,
          providerNames: widget.names,
          sourceFilter: widget.filter,
          onSelect: widget.onSelect ?? (_) {},
          onRetry: () => setState(() => retries++),
        ),
      ),
    ],
  );
}

void main() {
  late Directory logDir;
  final opened = <String>[];

  setUp(() {
    logDir = Directory.systemTemp.createTempSync('kanaru-picker-logs');
    opened.clear();
    addTearDown(() => logDir.deleteSync(recursive: true));
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        lyricsPluginLogDirProvider.overrideWithValue(logDir),
        showInFileManagerProvider.overrideWithValue((path) async {
          opened.add(path);
          return true;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );

  void writeLog(String id) =>
      File('${logDir.path}/$id.jsonl').writeAsStringSync('{}\n');

  final names = {
    'lrclib': 'LRCLIB',
    _plugin: 'NetEase · hieu05',
    _other: 'NetEase · other-dev',
  };

  group('results and the source filter', () {
    LyricsSearchState two() => LyricsSearchState(
      query: 'x',
      byProvider: const {
        'lrclib': ProviderSearchState(ProviderSearchPhase.done),
        _plugin: ProviderSearchState(ProviderSearchPhase.done),
      },
      results: [
        _result('lrclib', 'From lrclib'),
        _result(_plugin, 'From plugin'),
        _result('lrclib', 'Second lrclib'),
      ],
    );

    testWidgets('each result names its source', (tester) async {
      await pump(tester, _Host(state: two(), names: names));

      expect(find.text('LRCLIB'), findsNWidgets(2));
      expect(find.text('NetEase · hieu05'), findsOneWidget);
    });

    testWidgets('a filter narrows the list, a tap reports the full index', (
      tester,
    ) async {
      final selected = <int>[];
      await pump(
        tester,
        _Host(
          state: two(),
          names: names,
          onSelect: selected.add,
          filter: _plugin,
        ),
      );

      expect(find.text('From plugin'), findsOneWidget);
      expect(find.text('From lrclib'), findsNothing);
      expect(find.text('Second lrclib'), findsNothing);

      await tester.tap(find.text('From plugin'));
      expect(selected, [1]);
    });

    testWidgets('a filter on a source with no results shows everything', (
      tester,
    ) async {
      await pump(
        tester,
        LyricsPickerResultsPane(
          state: two(),
          providerNames: names,
          sourceFilter: _other,
          onSelect: (_) {},
          onRetry: () {},
        ),
      );

      expect(find.text('From plugin'), findsOneWidget);
      expect(find.text('From lrclib'), findsOneWidget);
    });
  });

  group('failure lines', () {
    LyricsSearchState failed(Map<String, LyricsFetchKind> kinds) =>
        LyricsSearchState(
          query: 'x',
          byProvider: {
            for (final e in kinds.entries)
              e.key: ProviderSearchState(ProviderSearchPhase.error, e.value),
          },
        );

    testWidgets('name the plugin and why, with Retry and View log', (
      tester,
    ) async {
      writeLog(_other);
      await pump(
        tester,
        _Host(
          state: failed({
            _other: LyricsFetchKind.invalidResponse,
            'lrclib': LyricsFetchKind.network,
          }),
          names: names,
        ),
      );

      expect(
        find.text('NetEase · other-dev answered but Kanaru could not read it'),
        findsOneWidget,
      );
      expect(find.text("Couldn't reach LRCLIB"), findsOneWidget);
      expect(find.text('Retry'), findsNWidgets(2));
      // Only the plugin has a log.
      expect(find.text('View log'), findsOneWidget);

      await tester.tap(find.text('View log'));
      await tester.pump();
      expect(opened, ['${logDir.path}/$_other.jsonl']);

      await tester.tap(find.text('Retry').first);
      await tester.pump();
      expect(find.text('retries 1'), findsOneWidget);
    });

    testWidgets('View log is hidden while the plugin has no log file', (
      tester,
    ) async {
      await pump(
        tester,
        _Host(state: failed({_plugin: LyricsFetchKind.network}), names: names),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('View log'), findsNothing);
    });

    testWidgets('View log is hidden for LRCLIB', (tester) async {
      writeLog(_plugin);
      await pump(
        tester,
        _Host(state: failed({'lrclib': LyricsFetchKind.server}), names: names),
      );

      expect(find.text('View log'), findsNothing);
    });

    testWidgets('lines show above the results too', (tester) async {
      writeLog(_plugin);
      final state = LyricsSearchState(
        query: 'x',
        byProvider: const {
          'lrclib': ProviderSearchState(ProviderSearchPhase.done),
          _plugin: ProviderSearchState(
            ProviderSearchPhase.error,
            LyricsFetchKind.network,
          ),
        },
        results: [_result('lrclib', 'Found one')],
      );
      await pump(tester, _Host(state: state, names: names));

      expect(find.text('Found one'), findsOneWidget);
      expect(find.text("Couldn't reach NetEase · hieu05"), findsOneWidget);
      expect(find.text('View log'), findsOneWidget);
    });
  });
}
