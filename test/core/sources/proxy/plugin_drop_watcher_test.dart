import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/online_sources_prefs.dart';
import 'package:kanaru/core/sources/proxy/plugin_drop_watcher.dart';

import 'drop_test_support.dart';
import 'proxy_test_support.dart';

const _a = 'plugin-aaaaaaaaaaaa';
const _b = 'plugin-bbbbbbbbbbbb';

class _Target implements PluginDropTarget {
  final dropped = <String>[];
  final restored = <String>[];

  @override
  void dropPlugin(String installId) => dropped.add(installId);

  @override
  void restorePlugin(String installId) => restored.add(installId);
}

void main() {
  late DropTestState state;
  late ProviderContainer container;
  late _Target target;

  ProviderContainer make({
    AsyncValue<List<dynamic>>? records,
    Set<String> consented = const {_a, _b},
  }) {
    state = DropTestState(
      records: records == null
          ? AsyncValue.data([sourceRecord(_a), sourceRecord(_b)])
          : const AsyncValue.loading(),
      consented: consented,
    );
    target = _Target();
    final watched = Provider<_Target>((ref) {
      watchPluginDrops(ref, target);
      return target;
    });
    container = ProviderContainer(overrides: state.overrides);
    addTearDown(container.dispose);
    container.read(watched);
    return container;
  }

  /// Lets the containers' updates run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('a record that leaves the enabled source plugins is dropped', () async {
    make();
    state.recordsOf(container).ids([_b]);
    await until(() => target.dropped.isNotEmpty);
    expect(target.dropped, [_a]);
  });

  test('a withdrawn consent is dropped', () async {
    make();
    state.settingsOf(container).consent({_b});
    await until(() => target.dropped.isNotEmpty);
    expect(target.dropped, [_a]);
  });

  test('an unrelated settings change drops nothing', () async {
    make();
    final settings = state.settingsOf(container);
    settings.set(settings.state.copyWith(animations: false));
    // A new set with the same ids is no withdrawal either.
    settings.consent({_a, _b});
    await settle();
    expect(target.dropped, isEmpty);
    expect(target.restored, isEmpty);
  });

  test('nothing is dropped while the records are loading or failed; the next '
      'list is compared with the last one read', () async {
    make();
    final records = state.recordsOf(container);
    records.set(const AsyncValue.loading());
    await settle();
    records.set(AsyncValue.error(StateError('read failed'), StackTrace.empty));
    await settle();
    expect(target.dropped, isEmpty);

    records.ids([_b]);
    await until(() => target.dropped.isNotEmpty);
    expect(target.dropped, [_a]);
  });

  test('the first list read after a slow start drops nothing', () async {
    make(records: const AsyncValue.loading());
    state.recordsOf(container).ids([_b]);
    await settle();
    expect(target.dropped, isEmpty);
  });

  test('an id again in both is restored', () async {
    make();
    final settings = state.settingsOf(container);
    settings.consent({_b});
    await until(() => target.dropped.isNotEmpty);
    settings.consent({_a, _b});
    await until(() => target.restored.isNotEmpty);
    expect(target.restored, [_a]);

    final records = state.recordsOf(container);
    records.ids([_a]);
    await until(() => target.dropped.length == 2);
    records.ids([_a, _b]);
    await until(() => target.restored.length == 2);
    expect(target.restored, [_a, _b]);
  });

  test('accepting the notice of a plugin that is not installed restores '
      'nothing', () async {
    make(consented: {_a});
    state
        .settingsOf(container)
        .set(
          state
              .settingsOf(container)
              .state
              .copyWith(
                onlineSources: const OnlineSourcesPrefs(
                  noticeAcknowledged: {_a, 'plugin-cccccccccccc'},
                ),
              ),
        );
    await settle();
    expect(target.restored, isEmpty);
  });
}
