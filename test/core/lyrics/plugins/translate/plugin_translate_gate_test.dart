import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_gate.dart';

void main() {
  test('a task that throws still hands the turn on', () async {
    final gate = PluginTranslateGate();
    final hold = Completer<void>();
    final first = gate.run<void>(() => true, () async {
      await hold.future;
      throw StateError('boom');
    });
    final firstResult = expectLater(first, throwsStateError);
    final second = gate.run<String>(() => true, () async => 'ran');
    hold.complete();
    await firstResult;
    expect(await second, 'ran');
    expect(gate.waiting, 0);
    // The gate is free again.
    expect(await gate.run<int>(() => true, () async => 1), 1);
  });

  test('a dropped waiter hands the turn on', () async {
    final gate = PluginTranslateGate();
    final hold = Completer<void>();
    final first = gate.run<void>(() => true, () => hold.future);
    final dropped = expectLater(
      gate.run<void>(() => false, () async {}),
      throwsA(isA<TranslationSuperseded>()),
    );
    final third = gate.run<String>(() => true, () async => 'ran');
    hold.complete();
    await first;
    await dropped;
    expect(await third, 'ran');
  });
}
