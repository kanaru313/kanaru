import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kanaru/core/media_controls/media_controls_provider.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_media_controls.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/track.dart';

import '../player/fake_audio_backend.dart';

const mprisName = 'org.mpris.MediaPlayer2.kanaru';

/// Coalescing window of the controls under test; much shorter than
/// `defaultMprisCoalesceWindow`.
const harnessCoalesceWindow = Duration(milliseconds: 10);

/// How long a "nothing is sent" check waits: several windows plus socket
/// round trips.
const _quietTime = Duration(milliseconds: 60);

/// Longest wait for a signal that must arrive.
const _signalTimeout = Duration(seconds: 1);

final songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

/// An in-process bus (no `dbus-daemon`) with the app side and a second
/// client standing in for `playerctl`.
///
/// Waits use real time: the `dbus` sockets are real I/O, which `fakeAsync`
/// cannot drive. A signal that must arrive is awaited with [nextChange] or
/// [nextSeeked]; a signal that must not is ruled out by waiting [settle].
class MprisHarness {
  late final Directory _dir;
  late final DBusServer _server;
  late final DBusAddress _address;
  late final DBusClient app;
  late final DBusClient remoteClient;
  late final FakeAudioBackend backend;
  late final ProviderContainer container;
  late final DBusRemoteObject remote;
  final raised = <int>[];
  final clients = <DBusClient>[];
  MprisMediaControls? controls;
  final _changeEvents = StreamController<Map<String, DBusValue>>.broadcast();
  final _seekedEvents = StreamController<int>.broadcast();

  DBusAddress get address => _address;

  PlayerService get service => container.read(playerServiceProvider.notifier);

  /// [overrides] add to the player backend, e.g. a library and a covers
  /// folder for the art.
  Future<void> setUp({List<Override> overrides = const []}) async {
    _dir = await Directory.systemTemp.createTemp('kanaru-mpris');
    _server = DBusServer();
    _address = await _server.listenAddress(DBusAddress.unix(dir: _dir));
    app = newClient();
    remoteClient = newClient();
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        ...overrides,
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
  }

  DBusClient newClient() {
    final client = DBusClient(_address);
    clients.add(client);
    return client;
  }

  /// Creates the controls on the app client without waiting for the bus.
  /// [factory] replaces the client; [from] the container they read.
  MprisMediaControls create({
    String name = mprisName,
    DBusClient? client,
    DBusClient Function()? factory,
    ProviderContainer? from,
    Duration coalesceWindow = harnessCoalesceWindow,
    Map<String, DBusValue> Function(
      PlayerState,
      MprisTrackIds, {
      required String? artUri,
    })?
    buildProperties,
  }) {
    final provider = Provider(
      (ref) => MprisMediaControls(
        ref,
        factory ?? () => client ?? app,
        onRaise: () async => raised.add(raised.length),
        coalesceWindow: coalesceWindow,
        buildProperties: buildProperties ?? playerProperties,
      ),
    );
    // Listened like `main.dart` does, so what the controls listen to stays
    // active.
    controls = (from ?? container).listen(provider, (_, _) {}).read();
    pointRemoteAt(name);
    return controls!;
  }

  /// Aims [remote] at the service with [name].
  void pointRemoteAt([String name = mprisName]) {
    remote = DBusRemoteObject(
      remoteClient,
      name: name,
      path: DBusObjectPath(mprisObjectPath),
    );
  }

  /// A container wired like `main.dart`: the MPRIS controls are provided by
  /// an override on [app] and disposed with the container. [keepAlive]
  /// adds the container-level listener `main.dart` holds.
  ({ProviderContainer container, FakeAudioBackend backend}) appContainer({
    bool keepAlive = true,
  }) {
    final appBackend = FakeAudioBackend();
    final appContainer = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(appBackend),
        mediaControlsProvider.overrideWith((ref) {
          final controls = MprisMediaControls(
            ref,
            () => app,
            onRaise: () async => raised.add(raised.length),
            coalesceWindow: harnessCoalesceWindow,
          );
          ref.onDispose(controls.dispose);
          return controls;
        }),
      ],
    );
    if (keepAlive) appContainer.listen(mediaControlsProvider, (_, _) {});
    pointRemoteAt();
    return (container: appContainer, backend: appBackend);
  }

  /// Creates the controls and waits for [name] to appear.
  Future<MprisMediaControls> start({
    String name = mprisName,
    Duration coalesceWindow = harnessCoalesceWindow,
  }) async {
    create(name: name, coalesceWindow: coalesceWindow);
    await waitForName(name);
    return controls!;
  }

  Future<List<String>> names() => remoteClient.listNames();

  Future<void> waitForName(String name, {bool gone = false}) async {
    for (var i = 0; i < 100; i++) {
      if ((await names()).contains(name) != gone) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('$name ${gone ? 'never left' : 'never appeared'}');
  }

  /// Collects `PropertiesChanged` of the player interface. Returns once the
  /// bus has the match rule: the round trip on the same connection is
  /// answered after it.
  Future<List<Map<String, DBusValue>>> watchChanges() async {
    final changes = <Map<String, DBusValue>>[];
    remote.propertiesChanged
        .where((s) => s.propertiesInterface == mprisPlayerInterface)
        .listen((s) {
          changes.add(s.changedProperties);
          _changeEvents.add(s.changedProperties);
        });
    await names();
    return changes;
  }

  Future<List<int>> watchSeeked() async {
    final seeked = <int>[];
    DBusRemoteObjectSignalStream(
      object: remote,
      interface: mprisPlayerInterface,
      name: 'Seeked',
    ).listen((s) {
      final position = s.values[0].asInt64();
      seeked.add(position);
      _seekedEvents.add(position);
    });
    await names();
    return seeked;
  }

  /// The next `PropertiesChanged` seen by [watchChanges]. Call it before the
  /// action that causes the signal, then await it.
  Future<Map<String, DBusValue>> nextChange() =>
      _changeEvents.stream.first.timeout(_signalTimeout);

  /// The next `Seeked` seen by [watchSeeked]; use like [nextChange].
  Future<int> nextSeeked() =>
      _seekedEvents.stream.first.timeout(_signalTimeout);

  /// Runs [act] and waits for the `PropertiesChanged` it causes, then for
  /// [settle], so a second signal would be caught as well.
  Future<void> changeAfter(Future<void> Function() act) async {
    final next = nextChange();
    await act();
    await next;
    await settle();
  }

  /// For checks that nothing is sent: several coalescing windows plus a
  /// socket round trip.
  Future<void> settle([Duration time = _quietTime]) =>
      Future<void>.delayed(time);

  Future<DBusMethodSuccessResponse> call(
    String name, [
    List<DBusValue> values = const [],
    String interface = mprisPlayerInterface,
  ]) => remote.callMethod(interface, name, values);

  Future<void> tearDown() async {
    await controls?.dispose();
    container.dispose();
    await _changeEvents.close();
    await _seekedEvents.close();
    for (final client in clients) {
      await client.close();
    }
    await _server.close();
    await _dir.delete(recursive: true);
  }
}
