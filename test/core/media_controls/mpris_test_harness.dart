import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_media_controls.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';

import '../player/fake_audio_backend.dart';

const mprisName = 'org.mpris.MediaPlayer2.kanaru';

final songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

/// An in-process bus (no `dbus-daemon`) with the app side and a second
/// client standing in for `playerctl`.
///
/// Waits use real time: the `dbus` sockets are real I/O, which `fakeAsync`
/// cannot drive, so the 150ms coalescing window is waited out with [settle].
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

  PlayerService get service => container.read(playerServiceProvider.notifier);

  Future<void> setUp() async {
    _dir = await Directory.systemTemp.createTemp('kanaru-mpris');
    _server = DBusServer();
    _address = await _server.listenAddress(DBusAddress.unix(dir: _dir));
    app = newClient();
    remoteClient = newClient();
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    container.listen(playerServiceProvider, (_, _) {});
  }

  DBusClient newClient() {
    final client = DBusClient(_address);
    clients.add(client);
    return client;
  }

  /// Creates the controls on the app client without waiting for the bus.
  MprisMediaControls create({String name = mprisName}) {
    final provider = Provider(
      (ref) => MprisMediaControls(
        ref,
        app,
        onRaise: () async => raised.add(raised.length),
      ),
    );
    controls = container.read(provider);
    remote = DBusRemoteObject(
      remoteClient,
      name: name,
      path: DBusObjectPath(mprisObjectPath),
    );
    return controls!;
  }

  /// Creates the controls and waits for [name] to appear.
  Future<MprisMediaControls> start({String name = mprisName}) async {
    create(name: name);
    await waitForName(name);
    return controls!;
  }

  Future<List<String>> names() => remoteClient.listNames();

  Future<void> waitForName(String name) async {
    for (var i = 0; i < 100; i++) {
      if ((await names()).contains(name)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('$name never appeared: ${await names()}');
  }

  /// Collects `PropertiesChanged` of the player interface.
  Future<List<Map<String, DBusValue>>> watchChanges() async {
    final changes = <Map<String, DBusValue>>[];
    remote.propertiesChanged
        .where((s) => s.propertiesInterface == mprisPlayerInterface)
        .listen((s) => changes.add(s.changedProperties));
    await settle(const Duration(milliseconds: 100));
    return changes;
  }

  Future<List<int>> watchSeeked() async {
    final seeked = <int>[];
    DBusRemoteObjectSignalStream(
      object: remote,
      interface: mprisPlayerInterface,
      name: 'Seeked',
    ).listen((s) => seeked.add(s.values[0].asInt64()));
    await settle(const Duration(milliseconds: 100));
    return seeked;
  }

  /// Longer than the coalescing window plus a socket round trip.
  Future<void> settle([Duration time = const Duration(milliseconds: 400)]) =>
      Future<void>.delayed(time);

  Future<DBusMethodSuccessResponse> call(
    String name, [
    List<DBusValue> values = const [],
    String interface = mprisPlayerInterface,
  ]) => remote.callMethod(interface, name, values);

  Future<void> tearDown() async {
    await controls?.dispose();
    container.dispose();
    for (final client in clients) {
      await client.close();
    }
    await _server.close();
    await _dir.delete(recursive: true);
  }
}
