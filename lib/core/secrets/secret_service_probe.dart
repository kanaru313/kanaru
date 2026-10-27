import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

final _log = Logger('secrets');

const _serviceName = 'org.freedesktop.secrets';
const _servicePath = '/org/freedesktop/secrets';
const _serviceInterface = 'org.freedesktop.Secret.Service';
const _collectionInterface = 'org.freedesktop.Secret.Collection';

/// `errno` for a missing socket path.
const _enoent = 2;

/// How long the whole probe may take before it gives up as [unknown].
const _probeTimeout = Duration(seconds: 3);

/// What the session's Secret Service (GNOME Keyring, KWallet, KeePassXC...)
/// looks like right now.
enum SecretServiceStatus {
  /// Nobody owns the name and nothing can start it.
  absent,

  /// The default collection is locked: a call would wait for a prompt the
  /// user may never see.
  locked,

  /// A Secret Service runs but the `default` alias points nowhere, so there
  /// is no keyring to store into.
  noDefaultCollection,

  /// The default collection is unlocked.
  ready,

  /// The bus did not answer, or answered with an error.
  unknown,
}

/// The few D-Bus questions the probe asks. A fake in tests; the session bus
/// in the app.
abstract interface class SecretServiceBus {
  Future<List<String>> listNames();

  Future<List<String>> listActivatableNames();

  /// Object path of the `default` alias; `/` when the alias is not set.
  /// [listNames] throws [SecretServiceBusUnreachable] when the bus cannot be
  /// reached.
  Future<String> readDefaultAlias();

  Future<bool> isCollectionLocked(String collectionPath);

  Future<void> close();
}

/// The session bus does not exist (no bus address, no socket file), so there
/// is no Secret Service either. The store choice is made once per session, so
/// a bus that appears later is not noticed until restart.
class SecretServiceBusUnreachable implements Exception {
  const SecretServiceBusUnreachable();
}

/// Asks the session bus whether a Secret Service can be used without a
/// prompt. The Linux keyring plugin makes blocking calls on the UI thread,
/// so it is called only after this says `ready`. Never throws.
Future<SecretServiceStatus> probeSecretService({
  SecretServiceBus Function() openBus = DBusSecretServiceBus.new,
  Duration timeout = _probeTimeout,
}) async {
  SecretServiceBus? bus;
  try {
    bus = openBus();
    return await _probe(bus).timeout(timeout);
  } on SecretServiceBusUnreachable {
    return SecretServiceStatus.absent;
  } on Object catch (error) {
    _log.fine('Secret Service probe failed: ${error.runtimeType}');
    return SecretServiceStatus.unknown;
  } finally {
    final opened = bus;
    if (opened != null) {
      unawaited(opened.close().catchError((Object _) {}));
    }
  }
}

Future<SecretServiceStatus> _probe(SecretServiceBus bus) async {
  if (!(await bus.listNames()).contains(_serviceName) &&
      !(await bus.listActivatableNames()).contains(_serviceName)) {
    return SecretServiceStatus.absent;
  }
  // Starts an activatable service that is not running yet.
  final collection = await bus.readDefaultAlias();
  if (collection == '/') return SecretServiceStatus.noDefaultCollection;
  return await bus.isCollectionLocked(collection)
      ? SecretServiceStatus.locked
      : SecretServiceStatus.ready;
}

/// [SecretServiceBus] on the session bus.
class DBusSecretServiceBus implements SecretServiceBus {
  DBusSecretServiceBus([DBusClient? client])
    : _client = client ?? DBusClient.session();

  final DBusClient _client;

  @override
  Future<List<String>> listNames() async {
    // The first call opens the connection; failing to open it means there is
    // no bus, which is different from a bus that errors or is slow.
    try {
      return await _client.listNames();
    } on SocketException catch (error) {
      // Only a socket that does not exist (no bus address, or a path nobody
      // listens on) means "no bus". A refused or forbidden connection means a
      // bus that is there but unusable: that stays unknown, never the file.
      if (error.osError?.errorCode == _enoent) {
        throw const SecretServiceBusUnreachable();
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> listActivatableNames() => _client.listActivatableNames();

  @override
  Future<String> readDefaultAlias() async {
    final reply = await _client.callMethod(
      destination: _serviceName,
      path: DBusObjectPath(_servicePath),
      interface: _serviceInterface,
      name: 'ReadAlias',
      values: [const DBusString('default')],
      replySignature: DBusSignature('o'),
    );
    return reply.returnValues.first.asObjectPath().value;
  }

  @override
  Future<bool> isCollectionLocked(String collectionPath) async {
    final value = await DBusRemoteObject(
      _client,
      name: _serviceName,
      path: DBusObjectPath(collectionPath),
    ).getProperty(_collectionInterface, 'Locked');
    return value.asBoolean();
  }

  @override
  Future<void> close() => _client.close();
}
