import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../../player/player_state.dart';
import 'mpris_method_handler.dart';
import 'mpris_properties.dart';

/// `/org/mpris/MediaPlayer2` with the two MPRIS interfaces. `dbus` does not
/// catch what a handler throws, which leaves the caller waiting for a reply
/// that never comes, so every entry point turns errors into `Failed`.
class MprisObject extends DBusObject {
  MprisObject(this._handler, this._state, this._ids)
    : super(DBusObjectPath(mprisObjectPath));

  final MprisMethodHandler _handler;
  final PlayerState Function() _state;
  final MprisTrackIds _ids;

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
    try {
      return body();
    } catch (error, stack) {
      debugPrint('MPRIS $what failed: $error\n$stack');
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
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      mprisRootInterface,
      methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
      properties: [
        _read('CanQuit', 'b'),
        _read('Fullscreen', 'b'),
        _read('CanSetFullscreen', 'b'),
        _read('CanRaise', 'b'),
        _read('HasTrackList', 'b'),
        _read('Identity', 's'),
        _read('DesktopEntry', 's'),
        _read('SupportedUriSchemes', 'as'),
        _read('SupportedMimeTypes', 'as'),
      ],
    ),
    DBusIntrospectInterface(
      mprisPlayerInterface,
      methods: [
        for (final name in [
          'Next',
          'Previous',
          'Pause',
          'PlayPause',
          'Stop',
          'Play',
        ])
          DBusIntrospectMethod(name),
        DBusIntrospectMethod('Seek', args: [_in('x', 'Offset')]),
        DBusIntrospectMethod(
          'SetPosition',
          args: [_in('o', 'TrackId'), _in('x', 'Position')],
        ),
        DBusIntrospectMethod('OpenUri', args: [_in('s', 'Uri')]),
      ],
      signals: [
        DBusIntrospectSignal(
          'Seeked',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.out,
              name: 'Position',
            ),
          ],
        ),
      ],
      properties: [
        _read('PlaybackStatus', 's'),
        _write('LoopStatus', 's'),
        _write('Rate', 'd'),
        _write('Shuffle', 'b'),
        _read('Metadata', 'a{sv}'),
        _write('Volume', 'd'),
        _read('Position', 'x'),
        _read('MinimumRate', 'd'),
        _read('MaximumRate', 'd'),
        for (final name in [
          'CanGoNext',
          'CanGoPrevious',
          'CanPlay',
          'CanPause',
          'CanSeek',
          'CanControl',
        ])
          _read(name, 'b'),
      ],
    ),
  ];

  static DBusIntrospectProperty _read(String name, String type) =>
      DBusIntrospectProperty(
        name,
        DBusSignature(type),
        access: DBusPropertyAccess.read,
      );

  static DBusIntrospectProperty _write(String name, String type) =>
      DBusIntrospectProperty(name, DBusSignature(type));

  static DBusIntrospectArgument _in(String type, String name) =>
      DBusIntrospectArgument(
        DBusSignature(type),
        DBusArgumentDirection.in_,
        name: name,
      );
}
