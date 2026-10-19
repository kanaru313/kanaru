import 'dart:io' as io;

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

final _log = Logger('mpris');

const _busName = 'org.mpris.MediaPlayer2.kanaru';

/// How many `.instance<pid>_<n>` names to try after the plain ones.
const _maxExtraNames = 5;

/// First free name of: plain, `.instance<pid>`, `.instance<pid>_<n>`.
/// A hot restart keeps the old connection (and its name) alive, hence the
/// numbered ones. `null` when none is free or [cancelled] turns true.
Future<String?> acquireMprisBusName(
  DBusClient client, {
  required bool Function() cancelled,
}) async {
  final names = [
    _busName,
    '$_busName.instance${io.pid}',
    for (var n = 1; n <= _maxExtraNames; n++) '$_busName.instance${io.pid}_$n',
  ];
  for (final name in names) {
    if (cancelled()) return null;
    final reply = await client.requestName(
      name,
      flags: {DBusRequestNameFlag.doNotQueue},
    );
    if (reply == DBusRequestNameReply.primaryOwner ||
        reply == DBusRequestNameReply.alreadyOwner) {
      if (name != _busName) {
        _log.info('$_busName is taken, using $name');
      }
      return name;
    }
  }
  _log.warning('No free bus name, media controls are off');
  return null;
}
