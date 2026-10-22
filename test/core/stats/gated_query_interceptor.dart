import 'dart:async';

import 'package:drift/drift.dart';

/// Test-only [QueryInterceptor]: counts statements and can hold or fail the
/// next one that matches a pattern, to freeze the database mid-write.
class GatedQueryInterceptor extends QueryInterceptor {
  /// Every statement seen, in order.
  final statements = <String>[];

  Pattern? _holdPattern;
  Completer<void>? _gate;
  Pattern? _failPattern;

  /// How many statements matched [pattern] so far.
  int count(Pattern pattern) =>
      statements.where((s) => s.contains(pattern)).length;

  /// Holds the next statement matching [pattern] until the returned function
  /// is called.
  void Function() holdNext(Pattern pattern) {
    final gate = Completer<void>();
    _holdPattern = pattern;
    _gate = gate;
    return () {
      if (!gate.isCompleted) gate.complete();
    };
  }

  /// Makes the next statement matching [pattern] throw.
  void failNext(Pattern pattern) => _failPattern = pattern;

  Future<T> _run<T>(String statement, Future<T> Function() run) async {
    statements.add(statement);
    if (_failPattern != null && statement.contains(_failPattern!)) {
      _failPattern = null;
      throw StateError('injected failure');
    }
    final gate = _gate;
    if (gate != null && statement.contains(_holdPattern!)) {
      _gate = null;
      await gate.future;
    }
    return run();
  }

  @override
  Future<int> runInsert(QueryExecutor e, String s, List<Object?> a) =>
      _run(s, () => super.runInsert(e, s, a));

  @override
  Future<int> runUpdate(QueryExecutor e, String s, List<Object?> a) =>
      _run(s, () => super.runUpdate(e, s, a));

  @override
  Future<int> runDelete(QueryExecutor e, String s, List<Object?> a) =>
      _run(s, () => super.runDelete(e, s, a));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor e,
    String s,
    List<Object?> a,
  ) => _run(s, () => super.runSelect(e, s, a));
}
