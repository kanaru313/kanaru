import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/secrets/secret_service_probe.dart';

class _FakeBus implements SecretServiceBus {
  _FakeBus({
    this.names = const [],
    this.activatable = const [],
    this.alias = '/org/freedesktop/secrets/aliases/default',
    this.locked = false,
    this.fail = false,
    this.hang = false,
    this.unreachable = false,
  });

  final List<String> names;
  final List<String> activatable;
  final String alias;
  final bool locked;
  final bool fail;
  final bool hang;
  final bool unreachable;
  bool closed = false;

  Future<T> _answer<T>(T value) {
    if (unreachable) return Future.error(const SecretServiceBusUnreachable());
    if (hang) return Completer<T>().future;
    if (fail) return Future.error(StateError('bus error'));
    return Future.value(value);
  }

  @override
  Future<List<String>> listNames() => _answer(names);

  @override
  Future<List<String>> listActivatableNames() => _answer(activatable);

  @override
  Future<String> readDefaultAlias() => _answer(alias);

  @override
  Future<bool> isCollectionLocked(String collectionPath) => _answer(locked);

  @override
  Future<void> close() async => closed = true;
}

void main() {
  const name = 'org.freedesktop.secrets';

  Future<SecretServiceStatus> probe(_FakeBus bus) => probeSecretService(
    openBus: () => bus,
    timeout: const Duration(milliseconds: 50),
  );

  test('no owner and not activatable is absent', () async {
    expect(await probe(_FakeBus()), SecretServiceStatus.absent);
  });

  test('an unlocked default collection is ready', () async {
    final bus = _FakeBus(names: [name]);

    expect(await probe(bus), SecretServiceStatus.ready);
  });

  test('an activatable service that is not running is asked', () async {
    expect(
      await probe(_FakeBus(activatable: [name])),
      SecretServiceStatus.ready,
    );
  });

  test('a locked default collection is locked', () async {
    expect(
      await probe(_FakeBus(names: [name], locked: true)),
      SecretServiceStatus.locked,
    );
  });

  test('a missing default alias is its own status', () async {
    expect(
      await probe(_FakeBus(names: [name], alias: '/')),
      SecretServiceStatus.noDefaultCollection,
    );
  });

  test('a session bus that cannot be reached is absent', () async {
    expect(
      await probe(_FakeBus(unreachable: true)),
      SecretServiceStatus.absent,
    );
  });

  test('a bus error is unknown', () async {
    expect(await probe(_FakeBus(fail: true)), SecretServiceStatus.unknown);
  });

  test('a bus that does not answer is unknown', () async {
    expect(await probe(_FakeBus(hang: true)), SecretServiceStatus.unknown);
  });

  test('the bus is closed afterwards', () async {
    final bus = _FakeBus(names: [name]);
    await probe(bus);
    await Future<void>.delayed(Duration.zero);

    expect(bus.closed, isTrue);
  });

  group('connecting to a bus', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('kanaru_bus_'));
    tearDown(() => dir.deleteSync(recursive: true));

    DBusSecretServiceBus busAt(String socket) =>
        DBusSecretServiceBus(DBusClient(DBusAddress('unix:path=$socket')));

    test('a socket path that does not exist means no bus', () async {
      final bus = busAt('${dir.path}/missing');

      await expectLater(
        bus.listNames(),
        throwsA(isA<SecretServiceBusUnreachable>()),
      );
      await bus.close();
    });

    test('a refused connection is not treated as no bus', () async {
      final path = '${dir.path}/dead';
      // A file that is not a socket: connecting is refused, not missing.
      File(path).writeAsStringSync('');
      final bus = busAt(path);

      await expectLater(bus.listNames(), throwsA(isA<SocketException>()));
      await bus.close();
    });
  });
}
