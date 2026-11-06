import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/stream_proxy_server.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';
import 'package:kanaru/core/sources/source_plugin_drops.dart';

import 'drop_test_support.dart';
import 'proxy_test_support.dart';

const _other = 'plugin-zzzzzzzzzzzz';

void main() {
  late FakeUpstream upstream;
  late CountingResolver resolver;
  late DropTestState state;
  late ProviderContainer container;
  late List<String> dropped;
  const ref = RemoteSourceRef(installId: testInstallId, itemId: 'item');

  setUp(() async {
    upstream = await FakeUpstream.start(testBytes(100));
    addTearDown(upstream.close);
    resolver = CountingResolver(upstream);
    state = DropTestState(
      records: AsyncValue.data([
        sourceRecord(testInstallId),
        sourceRecord(_other),
      ]),
      consented: {testInstallId, _other},
    );
    container = ProviderContainer(
      overrides: [
        ...state.overrides,
        trackStreamResolversProvider.overrideWithValue({
          RemoteStreamKind.sourcePlugin: resolver,
        }),
      ],
    );
    addTearDown(container.dispose);
    dropped = [];
    final sub = container
        .read(sourcePluginDropsProvider)
        .stream
        .listen(dropped.add);
    addTearDown(sub.cancel);
  });

  StreamProxyServer proxy() => container.read(sourceStreamProxyProvider);

  Future<Uri> urlFor() async => Uri.parse(await proxy().urlFor(ref));

  test('removing the source record: the next request is 404 without a '
      'stream.js call, and the drop is signalled', () async {
    final url = await urlFor();
    state.recordsOf(container).ids([_other]);
    await until(() => dropped.isNotEmpty);

    final answer = await rawRequest(url, range: 'bytes=0-');
    expect(answer.status, 404);
    expect(resolver.calls, isEmpty);
    expect(dropped, [testInstallId]);
  });

  test('withdrawing its consent: the next request is 404 without a '
      'stream.js call, and the drop is signalled', () async {
    final url = await urlFor();
    state.settingsOf(container).consent({_other});
    await until(() => dropped.isNotEmpty);

    final answer = await rawRequest(url, range: 'bytes=0-');
    expect(answer.status, 404);
    expect(resolver.calls, isEmpty);
    expect(dropped, [testInstallId]);
  });

  test('an unrelated settings change drops nothing and keeps the port and '
      'the token', () async {
    final before = await urlFor();
    final settings = state.settingsOf(container);
    settings.set(settings.state.copyWith(animations: false));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final after = await urlFor();
    expect(after, before);
    final answer = await rawRequest(after, range: 'bytes=0-');
    // Served (resolved), not refused as dropped. The app's upstream client
    // connects to public addresses only, so the loopback stand-in for the
    // audio host is refused: 502.
    expect(answer.status, 502);
    expect(resolver.calls, [false]);
    expect(upstream.requests, isEmpty);
    expect(dropped, isEmpty);
  });

  test('the proxy is closed with its container', () async {
    final url = await urlFor();
    container.dispose();
    await expectLater(rawRequest(url), throwsA(isA<Object>()));
  });
}
