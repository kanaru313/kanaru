import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../player/player_state.dart';
import 'mpris_introspection.dart';
import 'mpris_method_handler.dart';
import 'mpris_properties.dart';

final _log = Logger('mpris');

/// `/org/mpris/MediaPlayer2` with the two MPRIS interfaces. `dbus` does not
/// catch what a handler throws, which leaves the caller waiting for a reply
/// that never comes, so every entry point turns errors into `Failed`.
class MprisObject extends DBusObject {
  MprisObject(this._handler, this._state, this._ids, this._isActive)
    : super(DBusObjectPath(mprisObjectPath));

  final MprisMethodHandler _handler;
  final PlayerState Function() _state;
  final MprisTrackIds _ids;

  /// False once the owner is disposed; the player state is then out of reach.
  final bool Function() _isActive;

  /// Properties of [interface], or `null` for an interface we do not have.
  Map<String, DBusValue>? _properties(String interface) {
    switch (interface) {
      case mprisRootInterface:
        return rootProperties();
      case mprisPlayerInterface:
        final state = _state();
        _ids.observe(state.queue);
        return playerProperties(state, _ids);
      default:
        return null;
    }
  }

  Future<DBusMethodResponse> _guard(
    String what,
    DBusMethodResponse Function() body,
  ) async {
    if (!_isActive()) return DBusMethodErrorResponse.failed();
    try {
      return body();
    } catch (error, stack) {
      _log.severe('$what failed', error, stack);
      return DBusMethodErrorResponse.failed();
    }
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) =>
      _guard(methodCall.name, () {
        _ids.observe(_state().queue);
        return switch (methodCall.interface) {
          mprisRootInterface => _handler.root(methodCall),
          mprisPlayerInterface => _handler.player(methodCall),
          _ => DBusMethodErrorResponse.unknownInterface(),
        };
      });

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) =>
      _guard('Get $name', () {
        final properties = _properties(interface);
        if (properties == null) {
          return DBusMethodErrorResponse.unknownInterface();
        }
        final value = properties[name];
        if (value == null) return DBusMethodErrorResponse.unknownProperty();
        return DBusGetPropertyResponse(value);
      });

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) =>
      _guard('GetAll', () {
        final properties = _properties(interface);
        if (properties == null) {
          return DBusMethodErrorResponse.unknownInterface();
        }
        return DBusGetAllPropertiesResponse(properties);
      });

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) => _guard('Set $name', () {
    _ids.observe(_state().queue);
    return switch (interface) {
      mprisPlayerInterface => _handler.setPlayerProperty(name, value),
      mprisRootInterface =>
        rootProperties().containsKey(name)
            ? DBusMethodErrorResponse.propertyReadOnly()
            : DBusMethodErrorResponse.unknownProperty(),
      _ => DBusMethodErrorResponse.unknownInterface(),
    };
  });

  @override
  List<DBusIntrospectInterface> introspect() => mprisIntrospection();
}
