import 'package:dbus/dbus.dart';

import 'mpris_properties.dart';

/// The two MPRIS interfaces as `Introspect` reports them.
List<DBusIntrospectInterface> mprisIntrospection() => [
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
      _read('Position', 'x', emitsChange: false),
      _read('MinimumRate', 'd'),
      _read('MaximumRate', 'd'),
      for (final name in [
        'CanGoNext',
        'CanGoPrevious',
        'CanPlay',
        'CanPause',
        'CanSeek',
      ])
        _read(name, 'b'),
      _read('CanControl', 'b', emitsChange: false),
    ],
  ),
];

/// [emitsChange] false marks properties that never come in
/// `PropertiesChanged` (Position, CanControl), so proxies built from
/// introspection read them instead of caching.
DBusIntrospectProperty _read(
  String name,
  String type, {
  bool emitsChange = true,
}) => DBusIntrospectProperty(
  name,
  DBusSignature(type),
  access: DBusPropertyAccess.read,
  annotations: [
    if (!emitsChange)
      DBusIntrospectAnnotation(
        'org.freedesktop.DBus.Property.EmitsChangedSignal',
        'false',
      ),
  ],
);

DBusIntrospectProperty _write(String name, String type) =>
    DBusIntrospectProperty(name, DBusSignature(type));

DBusIntrospectArgument _in(String type, String name) => DBusIntrospectArgument(
  DBusSignature(type),
  DBusArgumentDirection.in_,
  name: name,
);
