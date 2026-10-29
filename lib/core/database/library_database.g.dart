// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $PlaysTable extends Plays with TableInfo<$PlaysTable, Play> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, playedAt, listenedMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plays';
  @override
  VerificationContext validateIntegrity(
    Insertable<Play> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Play map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Play(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      ),
    );
  }

  @override
  $PlaysTable createAlias(String alias) {
    return $PlaysTable(attachedDatabase, alias);
  }
}

class Play extends DataClass implements Insertable<Play> {
  final int id;

  /// Canonical `tracks.path` spelling; deliberately no foreign key.
  final String path;

  /// When playback of this play started.
  final int playedAt;

  /// Accumulated listening time; null when unknown (for example an import).
  final int? listenedMs;
  const Play({
    required this.id,
    required this.path,
    required this.playedAt,
    this.listenedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['played_at'] = Variable<int>(playedAt);
    if (!nullToAbsent || listenedMs != null) {
      map['listened_ms'] = Variable<int>(listenedMs);
    }
    return map;
  }

  PlaysCompanion toCompanion(bool nullToAbsent) {
    return PlaysCompanion(
      id: Value(id),
      path: Value(path),
      playedAt: Value(playedAt),
      listenedMs: listenedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(listenedMs),
    );
  }

  factory Play.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Play(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      listenedMs: serializer.fromJson<int?>(json['listenedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'playedAt': serializer.toJson<int>(playedAt),
      'listenedMs': serializer.toJson<int?>(listenedMs),
    };
  }

  Play copyWith({
    int? id,
    String? path,
    int? playedAt,
    Value<int?> listenedMs = const Value.absent(),
  }) => Play(
    id: id ?? this.id,
    path: path ?? this.path,
    playedAt: playedAt ?? this.playedAt,
    listenedMs: listenedMs.present ? listenedMs.value : this.listenedMs,
  );
  Play copyWithCompanion(PlaysCompanion data) {
    return Play(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Play(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, playedAt, listenedMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Play &&
          other.id == this.id &&
          other.path == this.path &&
          other.playedAt == this.playedAt &&
          other.listenedMs == this.listenedMs);
}

class PlaysCompanion extends UpdateCompanion<Play> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> playedAt;
  final Value<int?> listenedMs;
  const PlaysCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
  });
  PlaysCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int playedAt,
    this.listenedMs = const Value.absent(),
  }) : path = Value(path),
       playedAt = Value(playedAt);
  static Insertable<Play> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? playedAt,
    Expression<int>? listenedMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (playedAt != null) 'played_at': playedAt,
      if (listenedMs != null) 'listened_ms': listenedMs,
    });
  }

  PlaysCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? playedAt,
    Value<int?>? listenedMs,
  }) {
    return PlaysCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      playedAt: playedAt ?? this.playedAt,
      listenedMs: listenedMs ?? this.listenedMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaysCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs')
          ..write(')'))
        .toString();
  }
}

class $PlayStatsTable extends PlayStats
    with TableInfo<$PlayStatsTable, PlayStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstPlayedAtMeta = const VerificationMeta(
    'firstPlayedAt',
  );
  @override
  late final GeneratedColumn<int> firstPlayedAt = GeneratedColumn<int>(
    'first_played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    playCount,
    firstPlayedAt,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    } else if (isInserting) {
      context.missing(_playCountMeta);
    }
    if (data.containsKey('first_played_at')) {
      context.handle(
        _firstPlayedAtMeta,
        firstPlayedAt.isAcceptableOrUnknown(
          data['first_played_at']!,
          _firstPlayedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstPlayedAtMeta);
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPlayedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  PlayStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayStat(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      firstPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_played_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      )!,
    );
  }

  @override
  $PlayStatsTable createAlias(String alias) {
    return $PlayStatsTable(attachedDatabase, alias);
  }
}

class PlayStat extends DataClass implements Insertable<PlayStat> {
  final String path;
  final int playCount;
  final int firstPlayedAt;
  final int lastPlayedAt;
  const PlayStat({
    required this.path,
    required this.playCount,
    required this.firstPlayedAt,
    required this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['play_count'] = Variable<int>(playCount);
    map['first_played_at'] = Variable<int>(firstPlayedAt);
    map['last_played_at'] = Variable<int>(lastPlayedAt);
    return map;
  }

  PlayStatsCompanion toCompanion(bool nullToAbsent) {
    return PlayStatsCompanion(
      path: Value(path),
      playCount: Value(playCount),
      firstPlayedAt: Value(firstPlayedAt),
      lastPlayedAt: Value(lastPlayedAt),
    );
  }

  factory PlayStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayStat(
      path: serializer.fromJson<String>(json['path']),
      playCount: serializer.fromJson<int>(json['playCount']),
      firstPlayedAt: serializer.fromJson<int>(json['firstPlayedAt']),
      lastPlayedAt: serializer.fromJson<int>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'playCount': serializer.toJson<int>(playCount),
      'firstPlayedAt': serializer.toJson<int>(firstPlayedAt),
      'lastPlayedAt': serializer.toJson<int>(lastPlayedAt),
    };
  }

  PlayStat copyWith({
    String? path,
    int? playCount,
    int? firstPlayedAt,
    int? lastPlayedAt,
  }) => PlayStat(
    path: path ?? this.path,
    playCount: playCount ?? this.playCount,
    firstPlayedAt: firstPlayedAt ?? this.firstPlayedAt,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
  );
  PlayStat copyWithCompanion(PlayStatsCompanion data) {
    return PlayStat(
      path: data.path.present ? data.path.value : this.path,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      firstPlayedAt: data.firstPlayedAt.present
          ? data.firstPlayedAt.value
          : this.firstPlayedAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayStat(')
          ..write('path: $path, ')
          ..write('playCount: $playCount, ')
          ..write('firstPlayedAt: $firstPlayedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, playCount, firstPlayedAt, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayStat &&
          other.path == this.path &&
          other.playCount == this.playCount &&
          other.firstPlayedAt == this.firstPlayedAt &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class PlayStatsCompanion extends UpdateCompanion<PlayStat> {
  final Value<String> path;
  final Value<int> playCount;
  final Value<int> firstPlayedAt;
  final Value<int> lastPlayedAt;
  final Value<int> rowid;
  const PlayStatsCompanion({
    this.path = const Value.absent(),
    this.playCount = const Value.absent(),
    this.firstPlayedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayStatsCompanion.insert({
    required String path,
    required int playCount,
    required int firstPlayedAt,
    required int lastPlayedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       playCount = Value(playCount),
       firstPlayedAt = Value(firstPlayedAt),
       lastPlayedAt = Value(lastPlayedAt);
  static Insertable<PlayStat> custom({
    Expression<String>? path,
    Expression<int>? playCount,
    Expression<int>? firstPlayedAt,
    Expression<int>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (playCount != null) 'play_count': playCount,
      if (firstPlayedAt != null) 'first_played_at': firstPlayedAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayStatsCompanion copyWith({
    Value<String>? path,
    Value<int>? playCount,
    Value<int>? firstPlayedAt,
    Value<int>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return PlayStatsCompanion(
      path: path ?? this.path,
      playCount: playCount ?? this.playCount,
      firstPlayedAt: firstPlayedAt ?? this.firstPlayedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (firstPlayedAt.present) {
      map['first_played_at'] = Variable<int>(firstPlayedAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayStatsCompanion(')
          ..write('path: $path, ')
          ..write('playCount: $playCount, ')
          ..write('firstPlayedAt: $firstPlayedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final int createdAt;

  /// Null for an ordinary playlist, 'favorites' for the Favorites playlist.
  final String? kind;
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      kind: serializer.fromJson<String?>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'kind': serializer.toJson<String?>(kind),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    int? createdAt,
    Value<String?> kind = const Value.absent(),
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    kind: kind.present ? kind.value : this.kind,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.kind == this.kind);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<String?> kind;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.kind = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int createdAt,
    this.kind = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<String>? kind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (kind != null) 'kind': kind,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<String?>? kind,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, playlistId, path, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntry extends DataClass implements Insertable<PlaylistEntry> {
  final int id;
  final int playlistId;

  /// Canonical `tracks.path` spelling; deliberately no foreign key.
  final String path;

  /// Dense 0..n-1 per playlist; not unique.
  final int position;
  const PlaylistEntry({
    required this.id,
    required this.playlistId,
    required this.path,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['path'] = Variable<String>(path);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      path: Value(path),
      position: Value(position),
    );
  }

  factory PlaylistEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntry(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      path: serializer.fromJson<String>(json['path']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'path': serializer.toJson<String>(path),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistEntry copyWith({
    int? id,
    int? playlistId,
    String? path,
    int? position,
  }) => PlaylistEntry(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    path: path ?? this.path,
    position: position ?? this.position,
  );
  PlaylistEntry copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntry(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      path: data.path.present ? data.path.value : this.path,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntry(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, path, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntry &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.path == this.path &&
          other.position == this.position);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntry> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> path;
  final Value<int> position;
  const PlaylistEntriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.path = const Value.absent(),
    this.position = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String path,
    required int position,
  }) : playlistId = Value(playlistId),
       path = Value(path),
       position = Value(position);
  static Insertable<PlaylistEntry> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? path,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (path != null) 'path': path,
      if (position != null) 'position': position,
    });
  }

  PlaylistEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? path,
    Value<int>? position,
  }) {
    return PlaylistEntriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      path: path ?? this.path,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('path: $path, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $LibraryRootsTable extends LibraryRoots
    with TableInfo<$LibraryRootsTable, LibraryRoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryRootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<int> lastScanAt = GeneratedColumn<int>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, addedAt, lastScanAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryRoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryRoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryRoot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scan_at'],
      ),
    );
  }

  @override
  $LibraryRootsTable createAlias(String alias) {
    return $LibraryRootsTable(attachedDatabase, alias);
  }
}

class LibraryRoot extends DataClass implements Insertable<LibraryRoot> {
  final int id;

  /// Canonical: symlinks resolved, no trailing slash.
  final String path;
  final int addedAt;

  /// Null until the first scan of this root finishes.
  final int? lastScanAt;
  const LibraryRoot({
    required this.id,
    required this.path,
    required this.addedAt,
    this.lastScanAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<int>(lastScanAt);
    }
    return map;
  }

  LibraryRootsCompanion toCompanion(bool nullToAbsent) {
    return LibraryRootsCompanion(
      id: Value(id),
      path: Value(path),
      addedAt: Value(addedAt),
      lastScanAt: lastScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanAt),
    );
  }

  factory LibraryRoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryRoot(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      lastScanAt: serializer.fromJson<int?>(json['lastScanAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<int>(addedAt),
      'lastScanAt': serializer.toJson<int?>(lastScanAt),
    };
  }

  LibraryRoot copyWith({
    int? id,
    String? path,
    int? addedAt,
    Value<int?> lastScanAt = const Value.absent(),
  }) => LibraryRoot(
    id: id ?? this.id,
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
  );
  LibraryRoot copyWithCompanion(LibraryRootsCompanion data) {
    return LibraryRoot(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRoot(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, addedAt, lastScanAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryRoot &&
          other.id == this.id &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.lastScanAt == this.lastScanAt);
}

class LibraryRootsCompanion extends UpdateCompanion<LibraryRoot> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> addedAt;
  final Value<int?> lastScanAt;
  const LibraryRootsCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
  });
  LibraryRootsCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int addedAt,
    this.lastScanAt = const Value.absent(),
  }) : path = Value(path),
       addedAt = Value(addedAt);
  static Insertable<LibraryRoot> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? addedAt,
    Expression<int>? lastScanAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
    });
  }

  LibraryRootsCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? addedAt,
    Value<int?>? lastScanAt,
  }) {
    return LibraryRootsCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<int>(lastScanAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRootsCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<int> rootId = GeneratedColumn<int>(
    'root_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_roots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNoMeta = const VerificationMeta(
    'trackNo',
  );
  @override
  late final GeneratedColumn<int> trackNo = GeneratedColumn<int>(
    'track_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackTotalMeta = const VerificationMeta(
    'trackTotal',
  );
  @override
  late final GeneratedColumn<int> trackTotal = GeneratedColumn<int>(
    'track_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNoMeta = const VerificationMeta('discNo');
  @override
  late final GeneratedColumn<int> discNo = GeneratedColumn<int>(
    'disc_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discTotalMeta = const VerificationMeta(
    'discTotal',
  );
  @override
  late final GeneratedColumn<int> discTotal = GeneratedColumn<int>(
    'disc_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _composerMeta = const VerificationMeta(
    'composer',
  );
  @override
  late final GeneratedColumn<String> composer = GeneratedColumn<String>(
    'composer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitDepthMeta = const VerificationMeta(
    'bitDepth',
  );
  @override
  late final GeneratedColumn<int> bitDepth = GeneratedColumn<int>(
    'bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanErrorMeta = const VerificationMeta(
    'scanError',
  );
  @override
  late final GeneratedColumn<String> scanError = GeneratedColumn<String>(
    'scan_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverKeyMeta = const VerificationMeta(
    'coverKey',
  );
  @override
  late final GeneratedColumn<String> coverKey = GeneratedColumn<String>(
    'cover_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverScanVersionMeta = const VerificationMeta(
    'coverScanVersion',
  );
  @override
  late final GeneratedColumn<int> coverScanVersion = GeneratedColumn<int>(
    'cover_scan_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _albumArtistKeyMeta = const VerificationMeta(
    'albumArtistKey',
  );
  @override
  late final GeneratedColumn<String> albumArtistKey = GeneratedColumn<String>(
    'album_artist_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumTitleKeyMeta = const VerificationMeta(
    'albumTitleKey',
  );
  @override
  late final GeneratedColumn<String> albumTitleKey = GeneratedColumn<String>(
    'album_title_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumDisplayArtistMeta =
      const VerificationMeta('albumDisplayArtist');
  @override
  late final GeneratedColumn<String> albumDisplayArtist =
      GeneratedColumn<String>(
        'album_display_artist',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _titleSortMeta = const VerificationMeta(
    'titleSort',
  );
  @override
  late final GeneratedColumn<String> titleSort = GeneratedColumn<String>(
    'title_sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _artistSortMeta = const VerificationMeta(
    'artistSort',
  );
  @override
  late final GeneratedColumn<String> artistSort = GeneratedColumn<String>(
    'artist_sort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumSortMeta = const VerificationMeta(
    'albumSort',
  );
  @override
  late final GeneratedColumn<String> albumSort = GeneratedColumn<String>(
    'album_sort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistSearchMeta = const VerificationMeta(
    'artistSearch',
  );
  @override
  late final GeneratedColumn<String> artistSearch = GeneratedColumn<String>(
    'artist_search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumSearchMeta = const VerificationMeta(
    'albumSearch',
  );
  @override
  late final GeneratedColumn<String> albumSearch = GeneratedColumn<String>(
    'album_search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistSearchMeta = const VerificationMeta(
    'albumArtistSearch',
  );
  @override
  late final GeneratedColumn<String> albumArtistSearch =
      GeneratedColumn<String>(
        'album_artist_search',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _genreSearchMeta = const VerificationMeta(
    'genreSearch',
  );
  @override
  late final GeneratedColumn<String> genreSearch = GeneratedColumn<String>(
    'genre_search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keysVersionMeta = const VerificationMeta(
    'keysVersion',
  );
  @override
  late final GeneratedColumn<int> keysVersion = GeneratedColumn<int>(
    'keys_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rootId,
    path,
    mtimeMs,
    sizeBytes,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    trackTotal,
    discNo,
    discTotal,
    year,
    genre,
    composer,
    comment,
    language,
    durationMs,
    bitrate,
    sampleRate,
    bitDepth,
    channels,
    addedAt,
    updatedAt,
    scanError,
    coverKey,
    coverScanVersion,
    albumArtistKey,
    albumTitleKey,
    albumDisplayArtist,
    titleSort,
    artistSort,
    albumSort,
    artistSearch,
    albumSearch,
    albumArtistSearch,
    genreSearch,
    keysVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rootIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMsMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('track_no')) {
      context.handle(
        _trackNoMeta,
        trackNo.isAcceptableOrUnknown(data['track_no']!, _trackNoMeta),
      );
    }
    if (data.containsKey('track_total')) {
      context.handle(
        _trackTotalMeta,
        trackTotal.isAcceptableOrUnknown(data['track_total']!, _trackTotalMeta),
      );
    }
    if (data.containsKey('disc_no')) {
      context.handle(
        _discNoMeta,
        discNo.isAcceptableOrUnknown(data['disc_no']!, _discNoMeta),
      );
    }
    if (data.containsKey('disc_total')) {
      context.handle(
        _discTotalMeta,
        discTotal.isAcceptableOrUnknown(data['disc_total']!, _discTotalMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('composer')) {
      context.handle(
        _composerMeta,
        composer.isAcceptableOrUnknown(data['composer']!, _composerMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('bit_depth')) {
      context.handle(
        _bitDepthMeta,
        bitDepth.isAcceptableOrUnknown(data['bit_depth']!, _bitDepthMeta),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('scan_error')) {
      context.handle(
        _scanErrorMeta,
        scanError.isAcceptableOrUnknown(data['scan_error']!, _scanErrorMeta),
      );
    }
    if (data.containsKey('cover_key')) {
      context.handle(
        _coverKeyMeta,
        coverKey.isAcceptableOrUnknown(data['cover_key']!, _coverKeyMeta),
      );
    }
    if (data.containsKey('cover_scan_version')) {
      context.handle(
        _coverScanVersionMeta,
        coverScanVersion.isAcceptableOrUnknown(
          data['cover_scan_version']!,
          _coverScanVersionMeta,
        ),
      );
    }
    if (data.containsKey('album_artist_key')) {
      context.handle(
        _albumArtistKeyMeta,
        albumArtistKey.isAcceptableOrUnknown(
          data['album_artist_key']!,
          _albumArtistKeyMeta,
        ),
      );
    }
    if (data.containsKey('album_title_key')) {
      context.handle(
        _albumTitleKeyMeta,
        albumTitleKey.isAcceptableOrUnknown(
          data['album_title_key']!,
          _albumTitleKeyMeta,
        ),
      );
    }
    if (data.containsKey('album_display_artist')) {
      context.handle(
        _albumDisplayArtistMeta,
        albumDisplayArtist.isAcceptableOrUnknown(
          data['album_display_artist']!,
          _albumDisplayArtistMeta,
        ),
      );
    }
    if (data.containsKey('title_sort')) {
      context.handle(
        _titleSortMeta,
        titleSort.isAcceptableOrUnknown(data['title_sort']!, _titleSortMeta),
      );
    }
    if (data.containsKey('artist_sort')) {
      context.handle(
        _artistSortMeta,
        artistSort.isAcceptableOrUnknown(data['artist_sort']!, _artistSortMeta),
      );
    }
    if (data.containsKey('album_sort')) {
      context.handle(
        _albumSortMeta,
        albumSort.isAcceptableOrUnknown(data['album_sort']!, _albumSortMeta),
      );
    }
    if (data.containsKey('artist_search')) {
      context.handle(
        _artistSearchMeta,
        artistSearch.isAcceptableOrUnknown(
          data['artist_search']!,
          _artistSearchMeta,
        ),
      );
    }
    if (data.containsKey('album_search')) {
      context.handle(
        _albumSearchMeta,
        albumSearch.isAcceptableOrUnknown(
          data['album_search']!,
          _albumSearchMeta,
        ),
      );
    }
    if (data.containsKey('album_artist_search')) {
      context.handle(
        _albumArtistSearchMeta,
        albumArtistSearch.isAcceptableOrUnknown(
          data['album_artist_search']!,
          _albumArtistSearchMeta,
        ),
      );
    }
    if (data.containsKey('genre_search')) {
      context.handle(
        _genreSearchMeta,
        genreSearch.isAcceptableOrUnknown(
          data['genre_search']!,
          _genreSearchMeta,
        ),
      );
    }
    if (data.containsKey('keys_version')) {
      context.handle(
        _keysVersionMeta,
        keysVersion.isAcceptableOrUnknown(
          data['keys_version']!,
          _keysVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}root_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      trackNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_no'],
      ),
      trackTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_total'],
      ),
      discNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_no'],
      ),
      discTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_total'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      composer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}composer'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      bitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_depth'],
      ),
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channels'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      scanError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_error'],
      ),
      coverKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_key'],
      ),
      coverScanVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_scan_version'],
      )!,
      albumArtistKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist_key'],
      ),
      albumTitleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_title_key'],
      ),
      albumDisplayArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_display_artist'],
      ),
      titleSort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_sort'],
      )!,
      artistSort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_sort'],
      ),
      albumSort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_sort'],
      ),
      artistSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_search'],
      ),
      albumSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_search'],
      ),
      albumArtistSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist_search'],
      ),
      genreSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre_search'],
      ),
      keysVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}keys_version'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class Track extends DataClass implements Insertable<Track> {
  final int id;

  /// Deleting a root removes its tracks.
  final int rootId;

  /// Absolute file path; the natural key used to match files on rescan.
  final String path;

  /// File modification time and size, compared on rescan to skip unchanged
  /// files.
  final int mtimeMs;
  final int sizeBytes;

  /// The tag title, else the file name.
  final String title;

  /// Multi-value tags are joined with "; ".
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNo;
  final int? trackTotal;
  final int? discNo;
  final int? discTotal;
  final int? year;
  final String? genre;
  final String? composer;
  final String? comment;

  /// The language tag as written, trimmed, at most 128 bytes. It may list
  /// several languages or use any naming; split and normalized at read time
  /// by `language_tags.dart`.
  final String? language;
  final int? durationMs;
  final int? bitrate;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;

  /// When the file was first indexed; never changes on rescan.
  final int addedAt;
  final int updatedAt;

  /// Why the tags could not be read; null when they were read fine.
  final String? scanError;

  /// Key of the cover thumbnail (a JPEG, longest side 512 px) in the cover
  /// cache folder: `<ab>/<hash>.jpg`, where `hash` is the blake3 of the
  /// original image bytes. Null when the track has no cover.
  final String? coverKey;

  /// The `coverScanVersion` (library_rows.dart) whose rules produced [coverKey]; 0 when the
  /// cover was never looked for. A lower value makes a rescan read the file
  /// again even when it is unchanged.
  final int coverScanVersion;

  /// Artist part of the album key; null when the track has no album.
  final String? albumArtistKey;

  /// Title part of the album key; null when the track has no album.
  final String? albumTitleKey;

  /// The album's artist as shown: the album artist tag, else the first track
  /// artist.
  final String? albumDisplayArtist;

  /// Sort keys of the title, the artist tag and the album; the last two are
  /// null with their text.
  final String titleSort;
  final String? artistSort;
  final String? albumSort;

  /// `sortKey` of the artist, album, album artist and genre tags (accents,
  /// case and đ folded; a leading "the" kept); null with their tag. Together
  /// with [titleSort] these are what `track_search` indexes.
  final String? artistSearch;
  final String? albumSearch;
  final String? albumArtistSearch;
  final String? genreSearch;

  /// The `textKeysVersion` whose rules produced the keys above; 0 when they
  /// were never computed.
  final int keysVersion;
  const Track({
    required this.id,
    required this.rootId,
    required this.path,
    required this.mtimeMs,
    required this.sizeBytes,
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNo,
    this.trackTotal,
    this.discNo,
    this.discTotal,
    this.year,
    this.genre,
    this.composer,
    this.comment,
    this.language,
    this.durationMs,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    required this.addedAt,
    required this.updatedAt,
    this.scanError,
    this.coverKey,
    required this.coverScanVersion,
    this.albumArtistKey,
    this.albumTitleKey,
    this.albumDisplayArtist,
    required this.titleSort,
    this.artistSort,
    this.albumSort,
    this.artistSearch,
    this.albumSearch,
    this.albumArtistSearch,
    this.genreSearch,
    required this.keysVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['root_id'] = Variable<int>(rootId);
    map['path'] = Variable<String>(path);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || trackNo != null) {
      map['track_no'] = Variable<int>(trackNo);
    }
    if (!nullToAbsent || trackTotal != null) {
      map['track_total'] = Variable<int>(trackTotal);
    }
    if (!nullToAbsent || discNo != null) {
      map['disc_no'] = Variable<int>(discNo);
    }
    if (!nullToAbsent || discTotal != null) {
      map['disc_total'] = Variable<int>(discTotal);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || composer != null) {
      map['composer'] = Variable<String>(composer);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || bitDepth != null) {
      map['bit_depth'] = Variable<int>(bitDepth);
    }
    if (!nullToAbsent || channels != null) {
      map['channels'] = Variable<int>(channels);
    }
    map['added_at'] = Variable<int>(addedAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || scanError != null) {
      map['scan_error'] = Variable<String>(scanError);
    }
    if (!nullToAbsent || coverKey != null) {
      map['cover_key'] = Variable<String>(coverKey);
    }
    map['cover_scan_version'] = Variable<int>(coverScanVersion);
    if (!nullToAbsent || albumArtistKey != null) {
      map['album_artist_key'] = Variable<String>(albumArtistKey);
    }
    if (!nullToAbsent || albumTitleKey != null) {
      map['album_title_key'] = Variable<String>(albumTitleKey);
    }
    if (!nullToAbsent || albumDisplayArtist != null) {
      map['album_display_artist'] = Variable<String>(albumDisplayArtist);
    }
    map['title_sort'] = Variable<String>(titleSort);
    if (!nullToAbsent || artistSort != null) {
      map['artist_sort'] = Variable<String>(artistSort);
    }
    if (!nullToAbsent || albumSort != null) {
      map['album_sort'] = Variable<String>(albumSort);
    }
    if (!nullToAbsent || artistSearch != null) {
      map['artist_search'] = Variable<String>(artistSearch);
    }
    if (!nullToAbsent || albumSearch != null) {
      map['album_search'] = Variable<String>(albumSearch);
    }
    if (!nullToAbsent || albumArtistSearch != null) {
      map['album_artist_search'] = Variable<String>(albumArtistSearch);
    }
    if (!nullToAbsent || genreSearch != null) {
      map['genre_search'] = Variable<String>(genreSearch);
    }
    map['keys_version'] = Variable<int>(keysVersion);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      rootId: Value(rootId),
      path: Value(path),
      mtimeMs: Value(mtimeMs),
      sizeBytes: Value(sizeBytes),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      trackNo: trackNo == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNo),
      trackTotal: trackTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(trackTotal),
      discNo: discNo == null && nullToAbsent
          ? const Value.absent()
          : Value(discNo),
      discTotal: discTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(discTotal),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      composer: composer == null && nullToAbsent
          ? const Value.absent()
          : Value(composer),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      bitDepth: bitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(bitDepth),
      channels: channels == null && nullToAbsent
          ? const Value.absent()
          : Value(channels),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
      scanError: scanError == null && nullToAbsent
          ? const Value.absent()
          : Value(scanError),
      coverKey: coverKey == null && nullToAbsent
          ? const Value.absent()
          : Value(coverKey),
      coverScanVersion: Value(coverScanVersion),
      albumArtistKey: albumArtistKey == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtistKey),
      albumTitleKey: albumTitleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(albumTitleKey),
      albumDisplayArtist: albumDisplayArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumDisplayArtist),
      titleSort: Value(titleSort),
      artistSort: artistSort == null && nullToAbsent
          ? const Value.absent()
          : Value(artistSort),
      albumSort: albumSort == null && nullToAbsent
          ? const Value.absent()
          : Value(albumSort),
      artistSearch: artistSearch == null && nullToAbsent
          ? const Value.absent()
          : Value(artistSearch),
      albumSearch: albumSearch == null && nullToAbsent
          ? const Value.absent()
          : Value(albumSearch),
      albumArtistSearch: albumArtistSearch == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtistSearch),
      genreSearch: genreSearch == null && nullToAbsent
          ? const Value.absent()
          : Value(genreSearch),
      keysVersion: Value(keysVersion),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<int>(json['id']),
      rootId: serializer.fromJson<int>(json['rootId']),
      path: serializer.fromJson<String>(json['path']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      trackNo: serializer.fromJson<int?>(json['trackNo']),
      trackTotal: serializer.fromJson<int?>(json['trackTotal']),
      discNo: serializer.fromJson<int?>(json['discNo']),
      discTotal: serializer.fromJson<int?>(json['discTotal']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      composer: serializer.fromJson<String?>(json['composer']),
      comment: serializer.fromJson<String?>(json['comment']),
      language: serializer.fromJson<String?>(json['language']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      bitDepth: serializer.fromJson<int?>(json['bitDepth']),
      channels: serializer.fromJson<int?>(json['channels']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      scanError: serializer.fromJson<String?>(json['scanError']),
      coverKey: serializer.fromJson<String?>(json['coverKey']),
      coverScanVersion: serializer.fromJson<int>(json['coverScanVersion']),
      albumArtistKey: serializer.fromJson<String?>(json['albumArtistKey']),
      albumTitleKey: serializer.fromJson<String?>(json['albumTitleKey']),
      albumDisplayArtist: serializer.fromJson<String?>(
        json['albumDisplayArtist'],
      ),
      titleSort: serializer.fromJson<String>(json['titleSort']),
      artistSort: serializer.fromJson<String?>(json['artistSort']),
      albumSort: serializer.fromJson<String?>(json['albumSort']),
      artistSearch: serializer.fromJson<String?>(json['artistSearch']),
      albumSearch: serializer.fromJson<String?>(json['albumSearch']),
      albumArtistSearch: serializer.fromJson<String?>(
        json['albumArtistSearch'],
      ),
      genreSearch: serializer.fromJson<String?>(json['genreSearch']),
      keysVersion: serializer.fromJson<int>(json['keysVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rootId': serializer.toJson<int>(rootId),
      'path': serializer.toJson<String>(path),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'trackNo': serializer.toJson<int?>(trackNo),
      'trackTotal': serializer.toJson<int?>(trackTotal),
      'discNo': serializer.toJson<int?>(discNo),
      'discTotal': serializer.toJson<int?>(discTotal),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'composer': serializer.toJson<String?>(composer),
      'comment': serializer.toJson<String?>(comment),
      'language': serializer.toJson<String?>(language),
      'durationMs': serializer.toJson<int?>(durationMs),
      'bitrate': serializer.toJson<int?>(bitrate),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'bitDepth': serializer.toJson<int?>(bitDepth),
      'channels': serializer.toJson<int?>(channels),
      'addedAt': serializer.toJson<int>(addedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'scanError': serializer.toJson<String?>(scanError),
      'coverKey': serializer.toJson<String?>(coverKey),
      'coverScanVersion': serializer.toJson<int>(coverScanVersion),
      'albumArtistKey': serializer.toJson<String?>(albumArtistKey),
      'albumTitleKey': serializer.toJson<String?>(albumTitleKey),
      'albumDisplayArtist': serializer.toJson<String?>(albumDisplayArtist),
      'titleSort': serializer.toJson<String>(titleSort),
      'artistSort': serializer.toJson<String?>(artistSort),
      'albumSort': serializer.toJson<String?>(albumSort),
      'artistSearch': serializer.toJson<String?>(artistSearch),
      'albumSearch': serializer.toJson<String?>(albumSearch),
      'albumArtistSearch': serializer.toJson<String?>(albumArtistSearch),
      'genreSearch': serializer.toJson<String?>(genreSearch),
      'keysVersion': serializer.toJson<int>(keysVersion),
    };
  }

  Track copyWith({
    int? id,
    int? rootId,
    String? path,
    int? mtimeMs,
    int? sizeBytes,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> albumArtist = const Value.absent(),
    Value<int?> trackNo = const Value.absent(),
    Value<int?> trackTotal = const Value.absent(),
    Value<int?> discNo = const Value.absent(),
    Value<int?> discTotal = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> composer = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> bitDepth = const Value.absent(),
    Value<int?> channels = const Value.absent(),
    int? addedAt,
    int? updatedAt,
    Value<String?> scanError = const Value.absent(),
    Value<String?> coverKey = const Value.absent(),
    int? coverScanVersion,
    Value<String?> albumArtistKey = const Value.absent(),
    Value<String?> albumTitleKey = const Value.absent(),
    Value<String?> albumDisplayArtist = const Value.absent(),
    String? titleSort,
    Value<String?> artistSort = const Value.absent(),
    Value<String?> albumSort = const Value.absent(),
    Value<String?> artistSearch = const Value.absent(),
    Value<String?> albumSearch = const Value.absent(),
    Value<String?> albumArtistSearch = const Value.absent(),
    Value<String?> genreSearch = const Value.absent(),
    int? keysVersion,
  }) => Track(
    id: id ?? this.id,
    rootId: rootId ?? this.rootId,
    path: path ?? this.path,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    trackNo: trackNo.present ? trackNo.value : this.trackNo,
    trackTotal: trackTotal.present ? trackTotal.value : this.trackTotal,
    discNo: discNo.present ? discNo.value : this.discNo,
    discTotal: discTotal.present ? discTotal.value : this.discTotal,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    composer: composer.present ? composer.value : this.composer,
    comment: comment.present ? comment.value : this.comment,
    language: language.present ? language.value : this.language,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    bitDepth: bitDepth.present ? bitDepth.value : this.bitDepth,
    channels: channels.present ? channels.value : this.channels,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    scanError: scanError.present ? scanError.value : this.scanError,
    coverKey: coverKey.present ? coverKey.value : this.coverKey,
    coverScanVersion: coverScanVersion ?? this.coverScanVersion,
    albumArtistKey: albumArtistKey.present
        ? albumArtistKey.value
        : this.albumArtistKey,
    albumTitleKey: albumTitleKey.present
        ? albumTitleKey.value
        : this.albumTitleKey,
    albumDisplayArtist: albumDisplayArtist.present
        ? albumDisplayArtist.value
        : this.albumDisplayArtist,
    titleSort: titleSort ?? this.titleSort,
    artistSort: artistSort.present ? artistSort.value : this.artistSort,
    albumSort: albumSort.present ? albumSort.value : this.albumSort,
    artistSearch: artistSearch.present ? artistSearch.value : this.artistSearch,
    albumSearch: albumSearch.present ? albumSearch.value : this.albumSearch,
    albumArtistSearch: albumArtistSearch.present
        ? albumArtistSearch.value
        : this.albumArtistSearch,
    genreSearch: genreSearch.present ? genreSearch.value : this.genreSearch,
    keysVersion: keysVersion ?? this.keysVersion,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      path: data.path.present ? data.path.value : this.path,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      trackNo: data.trackNo.present ? data.trackNo.value : this.trackNo,
      trackTotal: data.trackTotal.present
          ? data.trackTotal.value
          : this.trackTotal,
      discNo: data.discNo.present ? data.discNo.value : this.discNo,
      discTotal: data.discTotal.present ? data.discTotal.value : this.discTotal,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      composer: data.composer.present ? data.composer.value : this.composer,
      comment: data.comment.present ? data.comment.value : this.comment,
      language: data.language.present ? data.language.value : this.language,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      bitDepth: data.bitDepth.present ? data.bitDepth.value : this.bitDepth,
      channels: data.channels.present ? data.channels.value : this.channels,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      scanError: data.scanError.present ? data.scanError.value : this.scanError,
      coverKey: data.coverKey.present ? data.coverKey.value : this.coverKey,
      coverScanVersion: data.coverScanVersion.present
          ? data.coverScanVersion.value
          : this.coverScanVersion,
      albumArtistKey: data.albumArtistKey.present
          ? data.albumArtistKey.value
          : this.albumArtistKey,
      albumTitleKey: data.albumTitleKey.present
          ? data.albumTitleKey.value
          : this.albumTitleKey,
      albumDisplayArtist: data.albumDisplayArtist.present
          ? data.albumDisplayArtist.value
          : this.albumDisplayArtist,
      titleSort: data.titleSort.present ? data.titleSort.value : this.titleSort,
      artistSort: data.artistSort.present
          ? data.artistSort.value
          : this.artistSort,
      albumSort: data.albumSort.present ? data.albumSort.value : this.albumSort,
      artistSearch: data.artistSearch.present
          ? data.artistSearch.value
          : this.artistSearch,
      albumSearch: data.albumSearch.present
          ? data.albumSearch.value
          : this.albumSearch,
      albumArtistSearch: data.albumArtistSearch.present
          ? data.albumArtistSearch.value
          : this.albumArtistSearch,
      genreSearch: data.genreSearch.present
          ? data.genreSearch.value
          : this.genreSearch,
      keysVersion: data.keysVersion.present
          ? data.keysVersion.value
          : this.keysVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('path: $path, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('trackNo: $trackNo, ')
          ..write('trackTotal: $trackTotal, ')
          ..write('discNo: $discNo, ')
          ..write('discTotal: $discTotal, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('composer: $composer, ')
          ..write('comment: $comment, ')
          ..write('language: $language, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('channels: $channels, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scanError: $scanError, ')
          ..write('coverKey: $coverKey, ')
          ..write('coverScanVersion: $coverScanVersion, ')
          ..write('albumArtistKey: $albumArtistKey, ')
          ..write('albumTitleKey: $albumTitleKey, ')
          ..write('albumDisplayArtist: $albumDisplayArtist, ')
          ..write('titleSort: $titleSort, ')
          ..write('artistSort: $artistSort, ')
          ..write('albumSort: $albumSort, ')
          ..write('artistSearch: $artistSearch, ')
          ..write('albumSearch: $albumSearch, ')
          ..write('albumArtistSearch: $albumArtistSearch, ')
          ..write('genreSearch: $genreSearch, ')
          ..write('keysVersion: $keysVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    rootId,
    path,
    mtimeMs,
    sizeBytes,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    trackTotal,
    discNo,
    discTotal,
    year,
    genre,
    composer,
    comment,
    language,
    durationMs,
    bitrate,
    sampleRate,
    bitDepth,
    channels,
    addedAt,
    updatedAt,
    scanError,
    coverKey,
    coverScanVersion,
    albumArtistKey,
    albumTitleKey,
    albumDisplayArtist,
    titleSort,
    artistSort,
    albumSort,
    artistSearch,
    albumSearch,
    albumArtistSearch,
    genreSearch,
    keysVersion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.rootId == this.rootId &&
          other.path == this.path &&
          other.mtimeMs == this.mtimeMs &&
          other.sizeBytes == this.sizeBytes &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtist == this.albumArtist &&
          other.trackNo == this.trackNo &&
          other.trackTotal == this.trackTotal &&
          other.discNo == this.discNo &&
          other.discTotal == this.discTotal &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.composer == this.composer &&
          other.comment == this.comment &&
          other.language == this.language &&
          other.durationMs == this.durationMs &&
          other.bitrate == this.bitrate &&
          other.sampleRate == this.sampleRate &&
          other.bitDepth == this.bitDepth &&
          other.channels == this.channels &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt &&
          other.scanError == this.scanError &&
          other.coverKey == this.coverKey &&
          other.coverScanVersion == this.coverScanVersion &&
          other.albumArtistKey == this.albumArtistKey &&
          other.albumTitleKey == this.albumTitleKey &&
          other.albumDisplayArtist == this.albumDisplayArtist &&
          other.titleSort == this.titleSort &&
          other.artistSort == this.artistSort &&
          other.albumSort == this.albumSort &&
          other.artistSearch == this.artistSearch &&
          other.albumSearch == this.albumSearch &&
          other.albumArtistSearch == this.albumArtistSearch &&
          other.genreSearch == this.genreSearch &&
          other.keysVersion == this.keysVersion);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<int> id;
  final Value<int> rootId;
  final Value<String> path;
  final Value<int> mtimeMs;
  final Value<int> sizeBytes;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> albumArtist;
  final Value<int?> trackNo;
  final Value<int?> trackTotal;
  final Value<int?> discNo;
  final Value<int?> discTotal;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<String?> composer;
  final Value<String?> comment;
  final Value<String?> language;
  final Value<int?> durationMs;
  final Value<int?> bitrate;
  final Value<int?> sampleRate;
  final Value<int?> bitDepth;
  final Value<int?> channels;
  final Value<int> addedAt;
  final Value<int> updatedAt;
  final Value<String?> scanError;
  final Value<String?> coverKey;
  final Value<int> coverScanVersion;
  final Value<String?> albumArtistKey;
  final Value<String?> albumTitleKey;
  final Value<String?> albumDisplayArtist;
  final Value<String> titleSort;
  final Value<String?> artistSort;
  final Value<String?> albumSort;
  final Value<String?> artistSearch;
  final Value<String?> albumSearch;
  final Value<String?> albumArtistSearch;
  final Value<String?> genreSearch;
  final Value<int> keysVersion;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.rootId = const Value.absent(),
    this.path = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.trackTotal = const Value.absent(),
    this.discNo = const Value.absent(),
    this.discTotal = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.composer = const Value.absent(),
    this.comment = const Value.absent(),
    this.language = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.channels = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.scanError = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.coverScanVersion = const Value.absent(),
    this.albumArtistKey = const Value.absent(),
    this.albumTitleKey = const Value.absent(),
    this.albumDisplayArtist = const Value.absent(),
    this.titleSort = const Value.absent(),
    this.artistSort = const Value.absent(),
    this.albumSort = const Value.absent(),
    this.artistSearch = const Value.absent(),
    this.albumSearch = const Value.absent(),
    this.albumArtistSearch = const Value.absent(),
    this.genreSearch = const Value.absent(),
    this.keysVersion = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required int rootId,
    required String path,
    required int mtimeMs,
    required int sizeBytes,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.trackTotal = const Value.absent(),
    this.discNo = const Value.absent(),
    this.discTotal = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.composer = const Value.absent(),
    this.comment = const Value.absent(),
    this.language = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.channels = const Value.absent(),
    required int addedAt,
    required int updatedAt,
    this.scanError = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.coverScanVersion = const Value.absent(),
    this.albumArtistKey = const Value.absent(),
    this.albumTitleKey = const Value.absent(),
    this.albumDisplayArtist = const Value.absent(),
    this.titleSort = const Value.absent(),
    this.artistSort = const Value.absent(),
    this.albumSort = const Value.absent(),
    this.artistSearch = const Value.absent(),
    this.albumSearch = const Value.absent(),
    this.albumArtistSearch = const Value.absent(),
    this.genreSearch = const Value.absent(),
    this.keysVersion = const Value.absent(),
  }) : rootId = Value(rootId),
       path = Value(path),
       mtimeMs = Value(mtimeMs),
       sizeBytes = Value(sizeBytes),
       title = Value(title),
       addedAt = Value(addedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Track> custom({
    Expression<int>? id,
    Expression<int>? rootId,
    Expression<String>? path,
    Expression<int>? mtimeMs,
    Expression<int>? sizeBytes,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtist,
    Expression<int>? trackNo,
    Expression<int>? trackTotal,
    Expression<int>? discNo,
    Expression<int>? discTotal,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<String>? composer,
    Expression<String>? comment,
    Expression<String>? language,
    Expression<int>? durationMs,
    Expression<int>? bitrate,
    Expression<int>? sampleRate,
    Expression<int>? bitDepth,
    Expression<int>? channels,
    Expression<int>? addedAt,
    Expression<int>? updatedAt,
    Expression<String>? scanError,
    Expression<String>? coverKey,
    Expression<int>? coverScanVersion,
    Expression<String>? albumArtistKey,
    Expression<String>? albumTitleKey,
    Expression<String>? albumDisplayArtist,
    Expression<String>? titleSort,
    Expression<String>? artistSort,
    Expression<String>? albumSort,
    Expression<String>? artistSearch,
    Expression<String>? albumSearch,
    Expression<String>? albumArtistSearch,
    Expression<String>? genreSearch,
    Expression<int>? keysVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootId != null) 'root_id': rootId,
      if (path != null) 'path': path,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (trackNo != null) 'track_no': trackNo,
      if (trackTotal != null) 'track_total': trackTotal,
      if (discNo != null) 'disc_no': discNo,
      if (discTotal != null) 'disc_total': discTotal,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (composer != null) 'composer': composer,
      if (comment != null) 'comment': comment,
      if (language != null) 'language': language,
      if (durationMs != null) 'duration_ms': durationMs,
      if (bitrate != null) 'bitrate': bitrate,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      if (channels != null) 'channels': channels,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (scanError != null) 'scan_error': scanError,
      if (coverKey != null) 'cover_key': coverKey,
      if (coverScanVersion != null) 'cover_scan_version': coverScanVersion,
      if (albumArtistKey != null) 'album_artist_key': albumArtistKey,
      if (albumTitleKey != null) 'album_title_key': albumTitleKey,
      if (albumDisplayArtist != null)
        'album_display_artist': albumDisplayArtist,
      if (titleSort != null) 'title_sort': titleSort,
      if (artistSort != null) 'artist_sort': artistSort,
      if (albumSort != null) 'album_sort': albumSort,
      if (artistSearch != null) 'artist_search': artistSearch,
      if (albumSearch != null) 'album_search': albumSearch,
      if (albumArtistSearch != null) 'album_artist_search': albumArtistSearch,
      if (genreSearch != null) 'genre_search': genreSearch,
      if (keysVersion != null) 'keys_version': keysVersion,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<int>? rootId,
    Value<String>? path,
    Value<int>? mtimeMs,
    Value<int>? sizeBytes,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String?>? albumArtist,
    Value<int?>? trackNo,
    Value<int?>? trackTotal,
    Value<int?>? discNo,
    Value<int?>? discTotal,
    Value<int?>? year,
    Value<String?>? genre,
    Value<String?>? composer,
    Value<String?>? comment,
    Value<String?>? language,
    Value<int?>? durationMs,
    Value<int?>? bitrate,
    Value<int?>? sampleRate,
    Value<int?>? bitDepth,
    Value<int?>? channels,
    Value<int>? addedAt,
    Value<int>? updatedAt,
    Value<String?>? scanError,
    Value<String?>? coverKey,
    Value<int>? coverScanVersion,
    Value<String?>? albumArtistKey,
    Value<String?>? albumTitleKey,
    Value<String?>? albumDisplayArtist,
    Value<String>? titleSort,
    Value<String?>? artistSort,
    Value<String?>? albumSort,
    Value<String?>? artistSearch,
    Value<String?>? albumSearch,
    Value<String?>? albumArtistSearch,
    Value<String?>? genreSearch,
    Value<int>? keysVersion,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      rootId: rootId ?? this.rootId,
      path: path ?? this.path,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      trackNo: trackNo ?? this.trackNo,
      trackTotal: trackTotal ?? this.trackTotal,
      discNo: discNo ?? this.discNo,
      discTotal: discTotal ?? this.discTotal,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      composer: composer ?? this.composer,
      comment: comment ?? this.comment,
      language: language ?? this.language,
      durationMs: durationMs ?? this.durationMs,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scanError: scanError ?? this.scanError,
      coverKey: coverKey ?? this.coverKey,
      coverScanVersion: coverScanVersion ?? this.coverScanVersion,
      albumArtistKey: albumArtistKey ?? this.albumArtistKey,
      albumTitleKey: albumTitleKey ?? this.albumTitleKey,
      albumDisplayArtist: albumDisplayArtist ?? this.albumDisplayArtist,
      titleSort: titleSort ?? this.titleSort,
      artistSort: artistSort ?? this.artistSort,
      albumSort: albumSort ?? this.albumSort,
      artistSearch: artistSearch ?? this.artistSearch,
      albumSearch: albumSearch ?? this.albumSearch,
      albumArtistSearch: albumArtistSearch ?? this.albumArtistSearch,
      genreSearch: genreSearch ?? this.genreSearch,
      keysVersion: keysVersion ?? this.keysVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rootId.present) {
      map['root_id'] = Variable<int>(rootId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (trackNo.present) {
      map['track_no'] = Variable<int>(trackNo.value);
    }
    if (trackTotal.present) {
      map['track_total'] = Variable<int>(trackTotal.value);
    }
    if (discNo.present) {
      map['disc_no'] = Variable<int>(discNo.value);
    }
    if (discTotal.present) {
      map['disc_total'] = Variable<int>(discTotal.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (composer.present) {
      map['composer'] = Variable<String>(composer.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (bitDepth.present) {
      map['bit_depth'] = Variable<int>(bitDepth.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (scanError.present) {
      map['scan_error'] = Variable<String>(scanError.value);
    }
    if (coverKey.present) {
      map['cover_key'] = Variable<String>(coverKey.value);
    }
    if (coverScanVersion.present) {
      map['cover_scan_version'] = Variable<int>(coverScanVersion.value);
    }
    if (albumArtistKey.present) {
      map['album_artist_key'] = Variable<String>(albumArtistKey.value);
    }
    if (albumTitleKey.present) {
      map['album_title_key'] = Variable<String>(albumTitleKey.value);
    }
    if (albumDisplayArtist.present) {
      map['album_display_artist'] = Variable<String>(albumDisplayArtist.value);
    }
    if (titleSort.present) {
      map['title_sort'] = Variable<String>(titleSort.value);
    }
    if (artistSort.present) {
      map['artist_sort'] = Variable<String>(artistSort.value);
    }
    if (albumSort.present) {
      map['album_sort'] = Variable<String>(albumSort.value);
    }
    if (artistSearch.present) {
      map['artist_search'] = Variable<String>(artistSearch.value);
    }
    if (albumSearch.present) {
      map['album_search'] = Variable<String>(albumSearch.value);
    }
    if (albumArtistSearch.present) {
      map['album_artist_search'] = Variable<String>(albumArtistSearch.value);
    }
    if (genreSearch.present) {
      map['genre_search'] = Variable<String>(genreSearch.value);
    }
    if (keysVersion.present) {
      map['keys_version'] = Variable<int>(keysVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('rootId: $rootId, ')
          ..write('path: $path, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('trackNo: $trackNo, ')
          ..write('trackTotal: $trackTotal, ')
          ..write('discNo: $discNo, ')
          ..write('discTotal: $discTotal, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('composer: $composer, ')
          ..write('comment: $comment, ')
          ..write('language: $language, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('channels: $channels, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scanError: $scanError, ')
          ..write('coverKey: $coverKey, ')
          ..write('coverScanVersion: $coverScanVersion, ')
          ..write('albumArtistKey: $albumArtistKey, ')
          ..write('albumTitleKey: $albumTitleKey, ')
          ..write('albumDisplayArtist: $albumDisplayArtist, ')
          ..write('titleSort: $titleSort, ')
          ..write('artistSort: $artistSort, ')
          ..write('albumSort: $albumSort, ')
          ..write('artistSearch: $artistSearch, ')
          ..write('albumSearch: $albumSearch, ')
          ..write('albumArtistSearch: $albumArtistSearch, ')
          ..write('genreSearch: $genreSearch, ')
          ..write('keysVersion: $keysVersion')
          ..write(')'))
        .toString();
  }
}

class TrackSearch extends Table
    with
        TableInfo<TrackSearch, TrackSearchData>,
        VirtualTableInfo<TrackSearch, TrackSearchData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TrackSearch(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleSortMeta = const VerificationMeta(
    'titleSort',
  );
  late final GeneratedColumn<String> titleSort = GeneratedColumn<String>(
    'title_sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _artistSearchMeta = const VerificationMeta(
    'artistSearch',
  );
  late final GeneratedColumn<String> artistSearch = GeneratedColumn<String>(
    'artist_search',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _albumSearchMeta = const VerificationMeta(
    'albumSearch',
  );
  late final GeneratedColumn<String> albumSearch = GeneratedColumn<String>(
    'album_search',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _albumArtistSearchMeta = const VerificationMeta(
    'albumArtistSearch',
  );
  late final GeneratedColumn<String> albumArtistSearch =
      GeneratedColumn<String>(
        'album_artist_search',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: '',
      );
  static const VerificationMeta _genreSearchMeta = const VerificationMeta(
    'genreSearch',
  );
  late final GeneratedColumn<String> genreSearch = GeneratedColumn<String>(
    'genre_search',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    titleSort,
    artistSearch,
    albumSearch,
    albumArtistSearch,
    genreSearch,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackSearchData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_sort')) {
      context.handle(
        _titleSortMeta,
        titleSort.isAcceptableOrUnknown(data['title_sort']!, _titleSortMeta),
      );
    } else if (isInserting) {
      context.missing(_titleSortMeta);
    }
    if (data.containsKey('artist_search')) {
      context.handle(
        _artistSearchMeta,
        artistSearch.isAcceptableOrUnknown(
          data['artist_search']!,
          _artistSearchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_artistSearchMeta);
    }
    if (data.containsKey('album_search')) {
      context.handle(
        _albumSearchMeta,
        albumSearch.isAcceptableOrUnknown(
          data['album_search']!,
          _albumSearchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_albumSearchMeta);
    }
    if (data.containsKey('album_artist_search')) {
      context.handle(
        _albumArtistSearchMeta,
        albumArtistSearch.isAcceptableOrUnknown(
          data['album_artist_search']!,
          _albumArtistSearchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_albumArtistSearchMeta);
    }
    if (data.containsKey('genre_search')) {
      context.handle(
        _genreSearchMeta,
        genreSearch.isAcceptableOrUnknown(
          data['genre_search']!,
          _genreSearchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_genreSearchMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TrackSearchData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackSearchData(
      titleSort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_sort'],
      )!,
      artistSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_search'],
      )!,
      albumSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_search'],
      )!,
      albumArtistSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist_search'],
      )!,
      genreSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre_search'],
      )!,
    );
  }

  @override
  TrackSearch createAlias(String alias) {
    return TrackSearch(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title_sort, artist_search, album_search, album_artist_search, genre_search, content=\'tracks\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 0\', prefix=\'1 2 3\')';
}

class TrackSearchData extends DataClass implements Insertable<TrackSearchData> {
  final String titleSort;
  final String artistSearch;
  final String albumSearch;
  final String albumArtistSearch;
  final String genreSearch;
  const TrackSearchData({
    required this.titleSort,
    required this.artistSearch,
    required this.albumSearch,
    required this.albumArtistSearch,
    required this.genreSearch,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_sort'] = Variable<String>(titleSort);
    map['artist_search'] = Variable<String>(artistSearch);
    map['album_search'] = Variable<String>(albumSearch);
    map['album_artist_search'] = Variable<String>(albumArtistSearch);
    map['genre_search'] = Variable<String>(genreSearch);
    return map;
  }

  TrackSearchCompanion toCompanion(bool nullToAbsent) {
    return TrackSearchCompanion(
      titleSort: Value(titleSort),
      artistSearch: Value(artistSearch),
      albumSearch: Value(albumSearch),
      albumArtistSearch: Value(albumArtistSearch),
      genreSearch: Value(genreSearch),
    );
  }

  factory TrackSearchData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackSearchData(
      titleSort: serializer.fromJson<String>(json['title_sort']),
      artistSearch: serializer.fromJson<String>(json['artist_search']),
      albumSearch: serializer.fromJson<String>(json['album_search']),
      albumArtistSearch: serializer.fromJson<String>(
        json['album_artist_search'],
      ),
      genreSearch: serializer.fromJson<String>(json['genre_search']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title_sort': serializer.toJson<String>(titleSort),
      'artist_search': serializer.toJson<String>(artistSearch),
      'album_search': serializer.toJson<String>(albumSearch),
      'album_artist_search': serializer.toJson<String>(albumArtistSearch),
      'genre_search': serializer.toJson<String>(genreSearch),
    };
  }

  TrackSearchData copyWith({
    String? titleSort,
    String? artistSearch,
    String? albumSearch,
    String? albumArtistSearch,
    String? genreSearch,
  }) => TrackSearchData(
    titleSort: titleSort ?? this.titleSort,
    artistSearch: artistSearch ?? this.artistSearch,
    albumSearch: albumSearch ?? this.albumSearch,
    albumArtistSearch: albumArtistSearch ?? this.albumArtistSearch,
    genreSearch: genreSearch ?? this.genreSearch,
  );
  TrackSearchData copyWithCompanion(TrackSearchCompanion data) {
    return TrackSearchData(
      titleSort: data.titleSort.present ? data.titleSort.value : this.titleSort,
      artistSearch: data.artistSearch.present
          ? data.artistSearch.value
          : this.artistSearch,
      albumSearch: data.albumSearch.present
          ? data.albumSearch.value
          : this.albumSearch,
      albumArtistSearch: data.albumArtistSearch.present
          ? data.albumArtistSearch.value
          : this.albumArtistSearch,
      genreSearch: data.genreSearch.present
          ? data.genreSearch.value
          : this.genreSearch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackSearchData(')
          ..write('titleSort: $titleSort, ')
          ..write('artistSearch: $artistSearch, ')
          ..write('albumSearch: $albumSearch, ')
          ..write('albumArtistSearch: $albumArtistSearch, ')
          ..write('genreSearch: $genreSearch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    titleSort,
    artistSearch,
    albumSearch,
    albumArtistSearch,
    genreSearch,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackSearchData &&
          other.titleSort == this.titleSort &&
          other.artistSearch == this.artistSearch &&
          other.albumSearch == this.albumSearch &&
          other.albumArtistSearch == this.albumArtistSearch &&
          other.genreSearch == this.genreSearch);
}

class TrackSearchCompanion extends UpdateCompanion<TrackSearchData> {
  final Value<String> titleSort;
  final Value<String> artistSearch;
  final Value<String> albumSearch;
  final Value<String> albumArtistSearch;
  final Value<String> genreSearch;
  final Value<int> rowid;
  const TrackSearchCompanion({
    this.titleSort = const Value.absent(),
    this.artistSearch = const Value.absent(),
    this.albumSearch = const Value.absent(),
    this.albumArtistSearch = const Value.absent(),
    this.genreSearch = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackSearchCompanion.insert({
    required String titleSort,
    required String artistSearch,
    required String albumSearch,
    required String albumArtistSearch,
    required String genreSearch,
    this.rowid = const Value.absent(),
  }) : titleSort = Value(titleSort),
       artistSearch = Value(artistSearch),
       albumSearch = Value(albumSearch),
       albumArtistSearch = Value(albumArtistSearch),
       genreSearch = Value(genreSearch);
  static Insertable<TrackSearchData> custom({
    Expression<String>? titleSort,
    Expression<String>? artistSearch,
    Expression<String>? albumSearch,
    Expression<String>? albumArtistSearch,
    Expression<String>? genreSearch,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleSort != null) 'title_sort': titleSort,
      if (artistSearch != null) 'artist_search': artistSearch,
      if (albumSearch != null) 'album_search': albumSearch,
      if (albumArtistSearch != null) 'album_artist_search': albumArtistSearch,
      if (genreSearch != null) 'genre_search': genreSearch,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackSearchCompanion copyWith({
    Value<String>? titleSort,
    Value<String>? artistSearch,
    Value<String>? albumSearch,
    Value<String>? albumArtistSearch,
    Value<String>? genreSearch,
    Value<int>? rowid,
  }) {
    return TrackSearchCompanion(
      titleSort: titleSort ?? this.titleSort,
      artistSearch: artistSearch ?? this.artistSearch,
      albumSearch: albumSearch ?? this.albumSearch,
      albumArtistSearch: albumArtistSearch ?? this.albumArtistSearch,
      genreSearch: genreSearch ?? this.genreSearch,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleSort.present) {
      map['title_sort'] = Variable<String>(titleSort.value);
    }
    if (artistSearch.present) {
      map['artist_search'] = Variable<String>(artistSearch.value);
    }
    if (albumSearch.present) {
      map['album_search'] = Variable<String>(albumSearch.value);
    }
    if (albumArtistSearch.present) {
      map['album_artist_search'] = Variable<String>(albumArtistSearch.value);
    }
    if (genreSearch.present) {
      map['genre_search'] = Variable<String>(genreSearch.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackSearchCompanion(')
          ..write('titleSort: $titleSort, ')
          ..write('artistSearch: $artistSearch, ')
          ..write('albumSearch: $albumSearch, ')
          ..write('albumArtistSearch: $albumArtistSearch, ')
          ..write('genreSearch: $genreSearch, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackArtistsTable extends TrackArtists
    with TableInfo<$TrackArtistsTable, TrackArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _artistKeyMeta = const VerificationMeta(
    'artistKey',
  );
  @override
  late final GeneratedColumn<String> artistKey = GeneratedColumn<String>(
    'artist_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, artistKey, artistName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('artist_key')) {
      context.handle(
        _artistKeyMeta,
        artistKey.isAcceptableOrUnknown(data['artist_key']!, _artistKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_artistKeyMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistKey, trackId};
  @override
  TrackArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackArtist(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      artistKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_key'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      )!,
    );
  }

  @override
  $TrackArtistsTable createAlias(String alias) {
    return $TrackArtistsTable(attachedDatabase, alias);
  }
}

class TrackArtist extends DataClass implements Insertable<TrackArtist> {
  final int trackId;

  /// `groupKey` of the name.
  final String artistKey;

  /// The spelling seen first on this track.
  final String artistName;
  const TrackArtist({
    required this.trackId,
    required this.artistKey,
    required this.artistName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['artist_key'] = Variable<String>(artistKey);
    map['artist_name'] = Variable<String>(artistName);
    return map;
  }

  TrackArtistsCompanion toCompanion(bool nullToAbsent) {
    return TrackArtistsCompanion(
      trackId: Value(trackId),
      artistKey: Value(artistKey),
      artistName: Value(artistName),
    );
  }

  factory TrackArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackArtist(
      trackId: serializer.fromJson<int>(json['trackId']),
      artistKey: serializer.fromJson<String>(json['artistKey']),
      artistName: serializer.fromJson<String>(json['artistName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'artistKey': serializer.toJson<String>(artistKey),
      'artistName': serializer.toJson<String>(artistName),
    };
  }

  TrackArtist copyWith({int? trackId, String? artistKey, String? artistName}) =>
      TrackArtist(
        trackId: trackId ?? this.trackId,
        artistKey: artistKey ?? this.artistKey,
        artistName: artistName ?? this.artistName,
      );
  TrackArtist copyWithCompanion(TrackArtistsCompanion data) {
    return TrackArtist(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      artistKey: data.artistKey.present ? data.artistKey.value : this.artistKey,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackArtist(')
          ..write('trackId: $trackId, ')
          ..write('artistKey: $artistKey, ')
          ..write('artistName: $artistName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, artistKey, artistName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackArtist &&
          other.trackId == this.trackId &&
          other.artistKey == this.artistKey &&
          other.artistName == this.artistName);
}

class TrackArtistsCompanion extends UpdateCompanion<TrackArtist> {
  final Value<int> trackId;
  final Value<String> artistKey;
  final Value<String> artistName;
  final Value<int> rowid;
  const TrackArtistsCompanion({
    this.trackId = const Value.absent(),
    this.artistKey = const Value.absent(),
    this.artistName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackArtistsCompanion.insert({
    required int trackId,
    required String artistKey,
    required String artistName,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       artistKey = Value(artistKey),
       artistName = Value(artistName);
  static Insertable<TrackArtist> custom({
    Expression<int>? trackId,
    Expression<String>? artistKey,
    Expression<String>? artistName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (artistKey != null) 'artist_key': artistKey,
      if (artistName != null) 'artist_name': artistName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackArtistsCompanion copyWith({
    Value<int>? trackId,
    Value<String>? artistKey,
    Value<String>? artistName,
    Value<int>? rowid,
  }) {
    return TrackArtistsCompanion(
      trackId: trackId ?? this.trackId,
      artistKey: artistKey ?? this.artistKey,
      artistName: artistName ?? this.artistName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (artistKey.present) {
      map['artist_key'] = Variable<String>(artistKey.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackArtistsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('artistKey: $artistKey, ')
          ..write('artistName: $artistName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoverColorsTable extends CoverColors
    with TableInfo<$CoverColorsTable, CoverColor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoverColorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _coverKeyMeta = const VerificationMeta(
    'coverKey',
  );
  @override
  late final GeneratedColumn<String> coverKey = GeneratedColumn<String>(
    'cover_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paletteMeta = const VerificationMeta(
    'palette',
  );
  @override
  late final GeneratedColumn<String> palette = GeneratedColumn<String>(
    'palette',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algoVersionMeta = const VerificationMeta(
    'algoVersion',
  );
  @override
  late final GeneratedColumn<int> algoVersion = GeneratedColumn<int>(
    'algo_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [coverKey, seed, palette, algoVersion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cover_colors';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoverColor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cover_key')) {
      context.handle(
        _coverKeyMeta,
        coverKey.isAcceptableOrUnknown(data['cover_key']!, _coverKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_coverKeyMeta);
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    } else if (isInserting) {
      context.missing(_seedMeta);
    }
    if (data.containsKey('palette')) {
      context.handle(
        _paletteMeta,
        palette.isAcceptableOrUnknown(data['palette']!, _paletteMeta),
      );
    } else if (isInserting) {
      context.missing(_paletteMeta);
    }
    if (data.containsKey('algo_version')) {
      context.handle(
        _algoVersionMeta,
        algoVersion.isAcceptableOrUnknown(
          data['algo_version']!,
          _algoVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algoVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {coverKey};
  @override
  CoverColor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoverColor(
      coverKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_key'],
      )!,
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      )!,
      palette: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}palette'],
      )!,
      algoVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}algo_version'],
      )!,
    );
  }

  @override
  $CoverColorsTable createAlias(String alias) {
    return $CoverColorsTable(attachedDatabase, alias);
  }
}

class CoverColor extends DataClass implements Insertable<CoverColor> {
  final String coverKey;
  final int seed;
  final String palette;
  final int algoVersion;
  const CoverColor({
    required this.coverKey,
    required this.seed,
    required this.palette,
    required this.algoVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cover_key'] = Variable<String>(coverKey);
    map['seed'] = Variable<int>(seed);
    map['palette'] = Variable<String>(palette);
    map['algo_version'] = Variable<int>(algoVersion);
    return map;
  }

  CoverColorsCompanion toCompanion(bool nullToAbsent) {
    return CoverColorsCompanion(
      coverKey: Value(coverKey),
      seed: Value(seed),
      palette: Value(palette),
      algoVersion: Value(algoVersion),
    );
  }

  factory CoverColor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoverColor(
      coverKey: serializer.fromJson<String>(json['coverKey']),
      seed: serializer.fromJson<int>(json['seed']),
      palette: serializer.fromJson<String>(json['palette']),
      algoVersion: serializer.fromJson<int>(json['algoVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'coverKey': serializer.toJson<String>(coverKey),
      'seed': serializer.toJson<int>(seed),
      'palette': serializer.toJson<String>(palette),
      'algoVersion': serializer.toJson<int>(algoVersion),
    };
  }

  CoverColor copyWith({
    String? coverKey,
    int? seed,
    String? palette,
    int? algoVersion,
  }) => CoverColor(
    coverKey: coverKey ?? this.coverKey,
    seed: seed ?? this.seed,
    palette: palette ?? this.palette,
    algoVersion: algoVersion ?? this.algoVersion,
  );
  CoverColor copyWithCompanion(CoverColorsCompanion data) {
    return CoverColor(
      coverKey: data.coverKey.present ? data.coverKey.value : this.coverKey,
      seed: data.seed.present ? data.seed.value : this.seed,
      palette: data.palette.present ? data.palette.value : this.palette,
      algoVersion: data.algoVersion.present
          ? data.algoVersion.value
          : this.algoVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoverColor(')
          ..write('coverKey: $coverKey, ')
          ..write('seed: $seed, ')
          ..write('palette: $palette, ')
          ..write('algoVersion: $algoVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(coverKey, seed, palette, algoVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoverColor &&
          other.coverKey == this.coverKey &&
          other.seed == this.seed &&
          other.palette == this.palette &&
          other.algoVersion == this.algoVersion);
}

class CoverColorsCompanion extends UpdateCompanion<CoverColor> {
  final Value<String> coverKey;
  final Value<int> seed;
  final Value<String> palette;
  final Value<int> algoVersion;
  final Value<int> rowid;
  const CoverColorsCompanion({
    this.coverKey = const Value.absent(),
    this.seed = const Value.absent(),
    this.palette = const Value.absent(),
    this.algoVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoverColorsCompanion.insert({
    required String coverKey,
    required int seed,
    required String palette,
    required int algoVersion,
    this.rowid = const Value.absent(),
  }) : coverKey = Value(coverKey),
       seed = Value(seed),
       palette = Value(palette),
       algoVersion = Value(algoVersion);
  static Insertable<CoverColor> custom({
    Expression<String>? coverKey,
    Expression<int>? seed,
    Expression<String>? palette,
    Expression<int>? algoVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (coverKey != null) 'cover_key': coverKey,
      if (seed != null) 'seed': seed,
      if (palette != null) 'palette': palette,
      if (algoVersion != null) 'algo_version': algoVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoverColorsCompanion copyWith({
    Value<String>? coverKey,
    Value<int>? seed,
    Value<String>? palette,
    Value<int>? algoVersion,
    Value<int>? rowid,
  }) {
    return CoverColorsCompanion(
      coverKey: coverKey ?? this.coverKey,
      seed: seed ?? this.seed,
      palette: palette ?? this.palette,
      algoVersion: algoVersion ?? this.algoVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (coverKey.present) {
      map['cover_key'] = Variable<String>(coverKey.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (palette.present) {
      map['palette'] = Variable<String>(palette.value);
    }
    if (algoVersion.present) {
      map['algo_version'] = Variable<int>(algoVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoverColorsCompanion(')
          ..write('coverKey: $coverKey, ')
          ..write('seed: $seed, ')
          ..write('palette: $palette, ')
          ..write('algoVersion: $algoVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExcludedFoldersTable extends ExcludedFolders
    with TableInfo<$ExcludedFoldersTable, ExcludedFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExcludedFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'excluded_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExcludedFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExcludedFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExcludedFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ExcludedFoldersTable createAlias(String alias) {
    return $ExcludedFoldersTable(attachedDatabase, alias);
  }
}

class ExcludedFolder extends DataClass implements Insertable<ExcludedFolder> {
  final int id;
  final String path;
  final int addedAt;
  const ExcludedFolder({
    required this.id,
    required this.path,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  ExcludedFoldersCompanion toCompanion(bool nullToAbsent) {
    return ExcludedFoldersCompanion(
      id: Value(id),
      path: Value(path),
      addedAt: Value(addedAt),
    );
  }

  factory ExcludedFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExcludedFolder(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  ExcludedFolder copyWith({int? id, String? path, int? addedAt}) =>
      ExcludedFolder(
        id: id ?? this.id,
        path: path ?? this.path,
        addedAt: addedAt ?? this.addedAt,
      );
  ExcludedFolder copyWithCompanion(ExcludedFoldersCompanion data) {
    return ExcludedFolder(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExcludedFolder(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExcludedFolder &&
          other.id == this.id &&
          other.path == this.path &&
          other.addedAt == this.addedAt);
}

class ExcludedFoldersCompanion extends UpdateCompanion<ExcludedFolder> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> addedAt;
  const ExcludedFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ExcludedFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int addedAt,
  }) : path = Value(path),
       addedAt = Value(addedAt);
  static Insertable<ExcludedFolder> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ExcludedFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? addedAt,
  }) {
    return ExcludedFoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExcludedFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $LyricTranslationsTable extends LyricTranslations
    with TableInfo<$LyricTranslationsTable, LyricTranslationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricTranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLangMeta = const VerificationMeta(
    'targetLang',
  );
  @override
  late final GeneratedColumn<String> targetLang = GeneratedColumn<String>(
    'target_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceLangMeta = const VerificationMeta(
    'sourceLang',
  );
  @override
  late final GeneratedColumn<String> sourceLang = GeneratedColumn<String>(
    'source_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linesJsonMeta = const VerificationMeta(
    'linesJson',
  );
  @override
  late final GeneratedColumn<String> linesJson = GeneratedColumn<String>(
    'lines_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentHash,
    provider,
    targetLang,
    sourceLang,
    linesJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyric_translations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricTranslationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('target_lang')) {
      context.handle(
        _targetLangMeta,
        targetLang.isAcceptableOrUnknown(data['target_lang']!, _targetLangMeta),
      );
    } else if (isInserting) {
      context.missing(_targetLangMeta);
    }
    if (data.containsKey('source_lang')) {
      context.handle(
        _sourceLangMeta,
        sourceLang.isAcceptableOrUnknown(data['source_lang']!, _sourceLangMeta),
      );
    }
    if (data.containsKey('lines_json')) {
      context.handle(
        _linesJsonMeta,
        linesJson.isAcceptableOrUnknown(data['lines_json']!, _linesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_linesJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentHash, provider, targetLang};
  @override
  LyricTranslationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricTranslationRow(
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      targetLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_lang'],
      )!,
      sourceLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_lang'],
      ),
      linesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lines_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LyricTranslationsTable createAlias(String alias) {
    return $LyricTranslationsTable(attachedDatabase, alias);
  }
}

class LyricTranslationRow extends DataClass
    implements Insertable<LyricTranslationRow> {
  final String contentHash;

  /// 'google' or 'deepl'.
  final String provider;

  /// Internal language code, for example 'vi' or 'zh-Hans'.
  final String targetLang;

  /// Dominant detected base language code, when known.
  final String? sourceLang;

  /// `{"source line": "translation"}`.
  final String linesJson;
  final int createdAt;
  const LyricTranslationRow({
    required this.contentHash,
    required this.provider,
    required this.targetLang,
    this.sourceLang,
    required this.linesJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_hash'] = Variable<String>(contentHash);
    map['provider'] = Variable<String>(provider);
    map['target_lang'] = Variable<String>(targetLang);
    if (!nullToAbsent || sourceLang != null) {
      map['source_lang'] = Variable<String>(sourceLang);
    }
    map['lines_json'] = Variable<String>(linesJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LyricTranslationsCompanion toCompanion(bool nullToAbsent) {
    return LyricTranslationsCompanion(
      contentHash: Value(contentHash),
      provider: Value(provider),
      targetLang: Value(targetLang),
      sourceLang: sourceLang == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLang),
      linesJson: Value(linesJson),
      createdAt: Value(createdAt),
    );
  }

  factory LyricTranslationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricTranslationRow(
      contentHash: serializer.fromJson<String>(json['contentHash']),
      provider: serializer.fromJson<String>(json['provider']),
      targetLang: serializer.fromJson<String>(json['targetLang']),
      sourceLang: serializer.fromJson<String?>(json['sourceLang']),
      linesJson: serializer.fromJson<String>(json['linesJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentHash': serializer.toJson<String>(contentHash),
      'provider': serializer.toJson<String>(provider),
      'targetLang': serializer.toJson<String>(targetLang),
      'sourceLang': serializer.toJson<String?>(sourceLang),
      'linesJson': serializer.toJson<String>(linesJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LyricTranslationRow copyWith({
    String? contentHash,
    String? provider,
    String? targetLang,
    Value<String?> sourceLang = const Value.absent(),
    String? linesJson,
    int? createdAt,
  }) => LyricTranslationRow(
    contentHash: contentHash ?? this.contentHash,
    provider: provider ?? this.provider,
    targetLang: targetLang ?? this.targetLang,
    sourceLang: sourceLang.present ? sourceLang.value : this.sourceLang,
    linesJson: linesJson ?? this.linesJson,
    createdAt: createdAt ?? this.createdAt,
  );
  LyricTranslationRow copyWithCompanion(LyricTranslationsCompanion data) {
    return LyricTranslationRow(
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      provider: data.provider.present ? data.provider.value : this.provider,
      targetLang: data.targetLang.present
          ? data.targetLang.value
          : this.targetLang,
      sourceLang: data.sourceLang.present
          ? data.sourceLang.value
          : this.sourceLang,
      linesJson: data.linesJson.present ? data.linesJson.value : this.linesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricTranslationRow(')
          ..write('contentHash: $contentHash, ')
          ..write('provider: $provider, ')
          ..write('targetLang: $targetLang, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('linesJson: $linesJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    contentHash,
    provider,
    targetLang,
    sourceLang,
    linesJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricTranslationRow &&
          other.contentHash == this.contentHash &&
          other.provider == this.provider &&
          other.targetLang == this.targetLang &&
          other.sourceLang == this.sourceLang &&
          other.linesJson == this.linesJson &&
          other.createdAt == this.createdAt);
}

class LyricTranslationsCompanion extends UpdateCompanion<LyricTranslationRow> {
  final Value<String> contentHash;
  final Value<String> provider;
  final Value<String> targetLang;
  final Value<String?> sourceLang;
  final Value<String> linesJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const LyricTranslationsCompanion({
    this.contentHash = const Value.absent(),
    this.provider = const Value.absent(),
    this.targetLang = const Value.absent(),
    this.sourceLang = const Value.absent(),
    this.linesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricTranslationsCompanion.insert({
    required String contentHash,
    required String provider,
    required String targetLang,
    this.sourceLang = const Value.absent(),
    required String linesJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : contentHash = Value(contentHash),
       provider = Value(provider),
       targetLang = Value(targetLang),
       linesJson = Value(linesJson),
       createdAt = Value(createdAt);
  static Insertable<LyricTranslationRow> custom({
    Expression<String>? contentHash,
    Expression<String>? provider,
    Expression<String>? targetLang,
    Expression<String>? sourceLang,
    Expression<String>? linesJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentHash != null) 'content_hash': contentHash,
      if (provider != null) 'provider': provider,
      if (targetLang != null) 'target_lang': targetLang,
      if (sourceLang != null) 'source_lang': sourceLang,
      if (linesJson != null) 'lines_json': linesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricTranslationsCompanion copyWith({
    Value<String>? contentHash,
    Value<String>? provider,
    Value<String>? targetLang,
    Value<String?>? sourceLang,
    Value<String>? linesJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return LyricTranslationsCompanion(
      contentHash: contentHash ?? this.contentHash,
      provider: provider ?? this.provider,
      targetLang: targetLang ?? this.targetLang,
      sourceLang: sourceLang ?? this.sourceLang,
      linesJson: linesJson ?? this.linesJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (targetLang.present) {
      map['target_lang'] = Variable<String>(targetLang.value);
    }
    if (sourceLang.present) {
      map['source_lang'] = Variable<String>(sourceLang.value);
    }
    if (linesJson.present) {
      map['lines_json'] = Variable<String>(linesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricTranslationsCompanion(')
          ..write('contentHash: $contentHash, ')
          ..write('provider: $provider, ')
          ..write('targetLang: $targetLang, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('linesJson: $linesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricTranslationPrefsTable extends LyricTranslationPrefs
    with TableInfo<$LyricTranslationPrefsTable, LyricTranslationPrefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricTranslationPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLangMeta = const VerificationMeta(
    'targetLang',
  );
  @override
  late final GeneratedColumn<String> targetLang = GeneratedColumn<String>(
    'target_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [contentHash, targetLang];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyric_translation_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricTranslationPrefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('target_lang')) {
      context.handle(
        _targetLangMeta,
        targetLang.isAcceptableOrUnknown(data['target_lang']!, _targetLangMeta),
      );
    } else if (isInserting) {
      context.missing(_targetLangMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentHash};
  @override
  LyricTranslationPrefRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricTranslationPrefRow(
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      targetLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_lang'],
      )!,
    );
  }

  @override
  $LyricTranslationPrefsTable createAlias(String alias) {
    return $LyricTranslationPrefsTable(attachedDatabase, alias);
  }
}

class LyricTranslationPrefRow extends DataClass
    implements Insertable<LyricTranslationPrefRow> {
  final String contentHash;
  final String targetLang;
  const LyricTranslationPrefRow({
    required this.contentHash,
    required this.targetLang,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_hash'] = Variable<String>(contentHash);
    map['target_lang'] = Variable<String>(targetLang);
    return map;
  }

  LyricTranslationPrefsCompanion toCompanion(bool nullToAbsent) {
    return LyricTranslationPrefsCompanion(
      contentHash: Value(contentHash),
      targetLang: Value(targetLang),
    );
  }

  factory LyricTranslationPrefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricTranslationPrefRow(
      contentHash: serializer.fromJson<String>(json['contentHash']),
      targetLang: serializer.fromJson<String>(json['targetLang']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentHash': serializer.toJson<String>(contentHash),
      'targetLang': serializer.toJson<String>(targetLang),
    };
  }

  LyricTranslationPrefRow copyWith({String? contentHash, String? targetLang}) =>
      LyricTranslationPrefRow(
        contentHash: contentHash ?? this.contentHash,
        targetLang: targetLang ?? this.targetLang,
      );
  LyricTranslationPrefRow copyWithCompanion(
    LyricTranslationPrefsCompanion data,
  ) {
    return LyricTranslationPrefRow(
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      targetLang: data.targetLang.present
          ? data.targetLang.value
          : this.targetLang,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricTranslationPrefRow(')
          ..write('contentHash: $contentHash, ')
          ..write('targetLang: $targetLang')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentHash, targetLang);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricTranslationPrefRow &&
          other.contentHash == this.contentHash &&
          other.targetLang == this.targetLang);
}

class LyricTranslationPrefsCompanion
    extends UpdateCompanion<LyricTranslationPrefRow> {
  final Value<String> contentHash;
  final Value<String> targetLang;
  final Value<int> rowid;
  const LyricTranslationPrefsCompanion({
    this.contentHash = const Value.absent(),
    this.targetLang = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricTranslationPrefsCompanion.insert({
    required String contentHash,
    required String targetLang,
    this.rowid = const Value.absent(),
  }) : contentHash = Value(contentHash),
       targetLang = Value(targetLang);
  static Insertable<LyricTranslationPrefRow> custom({
    Expression<String>? contentHash,
    Expression<String>? targetLang,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentHash != null) 'content_hash': contentHash,
      if (targetLang != null) 'target_lang': targetLang,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricTranslationPrefsCompanion copyWith({
    Value<String>? contentHash,
    Value<String>? targetLang,
    Value<int>? rowid,
  }) {
    return LyricTranslationPrefsCompanion(
      contentHash: contentHash ?? this.contentHash,
      targetLang: targetLang ?? this.targetLang,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (targetLang.present) {
      map['target_lang'] = Variable<String>(targetLang.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricTranslationPrefsCompanion(')
          ..write('contentHash: $contentHash, ')
          ..write('targetLang: $targetLang, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnlineLyricsTable extends OnlineLyrics
    with TableInfo<$OnlineLyricsTable, OnlineLyricsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnlineLyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedTextMeta = const VerificationMeta(
    'syncedText',
  );
  @override
  late final GeneratedColumn<String> syncedText = GeneratedColumn<String>(
    'synced_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _instrumentalMeta = const VerificationMeta(
    'instrumental',
  );
  @override
  late final GeneratedColumn<bool> instrumental = GeneratedColumn<bool>(
    'instrumental',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("instrumental" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _remoteDurationMsMeta = const VerificationMeta(
    'remoteDurationMs',
  );
  @override
  late final GeneratedColumn<int> remoteDurationMs = GeneratedColumn<int>(
    'remote_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    providerId,
    status,
    remoteId,
    syncedText,
    plainText,
    instrumental,
    remoteDurationMs,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'online_lyrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnlineLyricsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('synced_text')) {
      context.handle(
        _syncedTextMeta,
        syncedText.isAcceptableOrUnknown(data['synced_text']!, _syncedTextMeta),
      );
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    }
    if (data.containsKey('instrumental')) {
      context.handle(
        _instrumentalMeta,
        instrumental.isAcceptableOrUnknown(
          data['instrumental']!,
          _instrumentalMeta,
        ),
      );
    }
    if (data.containsKey('remote_duration_ms')) {
      context.handle(
        _remoteDurationMsMeta,
        remoteDurationMs.isAcceptableOrUnknown(
          data['remote_duration_ms']!,
          _remoteDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey, providerId};
  @override
  OnlineLyricsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnlineLyricsRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      syncedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_text'],
      ),
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      ),
      instrumental: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}instrumental'],
      )!,
      remoteDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_duration_ms'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $OnlineLyricsTable createAlias(String alias) {
    return $OnlineLyricsTable(attachedDatabase, alias);
  }
}

class OnlineLyricsRow extends DataClass implements Insertable<OnlineLyricsRow> {
  final String cacheKey;
  final String providerId;

  /// 'found' or 'not_found'.
  final String status;

  /// The provider's id for the match; null when not found.
  final String? remoteId;
  final String? syncedText;
  final String? plainText;
  final bool instrumental;

  /// The duration the provider reports for the match.
  final int? remoteDurationMs;
  final int fetchedAt;
  const OnlineLyricsRow({
    required this.cacheKey,
    required this.providerId,
    required this.status,
    this.remoteId,
    this.syncedText,
    this.plainText,
    required this.instrumental,
    this.remoteDurationMs,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['provider_id'] = Variable<String>(providerId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || syncedText != null) {
      map['synced_text'] = Variable<String>(syncedText);
    }
    if (!nullToAbsent || plainText != null) {
      map['plain_text'] = Variable<String>(plainText);
    }
    map['instrumental'] = Variable<bool>(instrumental);
    if (!nullToAbsent || remoteDurationMs != null) {
      map['remote_duration_ms'] = Variable<int>(remoteDurationMs);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  OnlineLyricsCompanion toCompanion(bool nullToAbsent) {
    return OnlineLyricsCompanion(
      cacheKey: Value(cacheKey),
      providerId: Value(providerId),
      status: Value(status),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      syncedText: syncedText == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedText),
      plainText: plainText == null && nullToAbsent
          ? const Value.absent()
          : Value(plainText),
      instrumental: Value(instrumental),
      remoteDurationMs: remoteDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteDurationMs),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory OnlineLyricsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnlineLyricsRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      providerId: serializer.fromJson<String>(json['providerId']),
      status: serializer.fromJson<String>(json['status']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      syncedText: serializer.fromJson<String?>(json['syncedText']),
      plainText: serializer.fromJson<String?>(json['plainText']),
      instrumental: serializer.fromJson<bool>(json['instrumental']),
      remoteDurationMs: serializer.fromJson<int?>(json['remoteDurationMs']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'providerId': serializer.toJson<String>(providerId),
      'status': serializer.toJson<String>(status),
      'remoteId': serializer.toJson<String?>(remoteId),
      'syncedText': serializer.toJson<String?>(syncedText),
      'plainText': serializer.toJson<String?>(plainText),
      'instrumental': serializer.toJson<bool>(instrumental),
      'remoteDurationMs': serializer.toJson<int?>(remoteDurationMs),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  OnlineLyricsRow copyWith({
    String? cacheKey,
    String? providerId,
    String? status,
    Value<String?> remoteId = const Value.absent(),
    Value<String?> syncedText = const Value.absent(),
    Value<String?> plainText = const Value.absent(),
    bool? instrumental,
    Value<int?> remoteDurationMs = const Value.absent(),
    int? fetchedAt,
  }) => OnlineLyricsRow(
    cacheKey: cacheKey ?? this.cacheKey,
    providerId: providerId ?? this.providerId,
    status: status ?? this.status,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    syncedText: syncedText.present ? syncedText.value : this.syncedText,
    plainText: plainText.present ? plainText.value : this.plainText,
    instrumental: instrumental ?? this.instrumental,
    remoteDurationMs: remoteDurationMs.present
        ? remoteDurationMs.value
        : this.remoteDurationMs,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  OnlineLyricsRow copyWithCompanion(OnlineLyricsCompanion data) {
    return OnlineLyricsRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      status: data.status.present ? data.status.value : this.status,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      syncedText: data.syncedText.present
          ? data.syncedText.value
          : this.syncedText,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      instrumental: data.instrumental.present
          ? data.instrumental.value
          : this.instrumental,
      remoteDurationMs: data.remoteDurationMs.present
          ? data.remoteDurationMs.value
          : this.remoteDurationMs,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnlineLyricsRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('providerId: $providerId, ')
          ..write('status: $status, ')
          ..write('remoteId: $remoteId, ')
          ..write('syncedText: $syncedText, ')
          ..write('plainText: $plainText, ')
          ..write('instrumental: $instrumental, ')
          ..write('remoteDurationMs: $remoteDurationMs, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    providerId,
    status,
    remoteId,
    syncedText,
    plainText,
    instrumental,
    remoteDurationMs,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnlineLyricsRow &&
          other.cacheKey == this.cacheKey &&
          other.providerId == this.providerId &&
          other.status == this.status &&
          other.remoteId == this.remoteId &&
          other.syncedText == this.syncedText &&
          other.plainText == this.plainText &&
          other.instrumental == this.instrumental &&
          other.remoteDurationMs == this.remoteDurationMs &&
          other.fetchedAt == this.fetchedAt);
}

class OnlineLyricsCompanion extends UpdateCompanion<OnlineLyricsRow> {
  final Value<String> cacheKey;
  final Value<String> providerId;
  final Value<String> status;
  final Value<String?> remoteId;
  final Value<String?> syncedText;
  final Value<String?> plainText;
  final Value<bool> instrumental;
  final Value<int?> remoteDurationMs;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const OnlineLyricsCompanion({
    this.cacheKey = const Value.absent(),
    this.providerId = const Value.absent(),
    this.status = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.syncedText = const Value.absent(),
    this.plainText = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.remoteDurationMs = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnlineLyricsCompanion.insert({
    required String cacheKey,
    required String providerId,
    required String status,
    this.remoteId = const Value.absent(),
    this.syncedText = const Value.absent(),
    this.plainText = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.remoteDurationMs = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       providerId = Value(providerId),
       status = Value(status),
       fetchedAt = Value(fetchedAt);
  static Insertable<OnlineLyricsRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? providerId,
    Expression<String>? status,
    Expression<String>? remoteId,
    Expression<String>? syncedText,
    Expression<String>? plainText,
    Expression<bool>? instrumental,
    Expression<int>? remoteDurationMs,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (providerId != null) 'provider_id': providerId,
      if (status != null) 'status': status,
      if (remoteId != null) 'remote_id': remoteId,
      if (syncedText != null) 'synced_text': syncedText,
      if (plainText != null) 'plain_text': plainText,
      if (instrumental != null) 'instrumental': instrumental,
      if (remoteDurationMs != null) 'remote_duration_ms': remoteDurationMs,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnlineLyricsCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? providerId,
    Value<String>? status,
    Value<String?>? remoteId,
    Value<String?>? syncedText,
    Value<String?>? plainText,
    Value<bool>? instrumental,
    Value<int?>? remoteDurationMs,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return OnlineLyricsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      providerId: providerId ?? this.providerId,
      status: status ?? this.status,
      remoteId: remoteId ?? this.remoteId,
      syncedText: syncedText ?? this.syncedText,
      plainText: plainText ?? this.plainText,
      instrumental: instrumental ?? this.instrumental,
      remoteDurationMs: remoteDurationMs ?? this.remoteDurationMs,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (syncedText.present) {
      map['synced_text'] = Variable<String>(syncedText.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (instrumental.present) {
      map['instrumental'] = Variable<bool>(instrumental.value);
    }
    if (remoteDurationMs.present) {
      map['remote_duration_ms'] = Variable<int>(remoteDurationMs.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnlineLyricsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('providerId: $providerId, ')
          ..write('status: $status, ')
          ..write('remoteId: $remoteId, ')
          ..write('syncedText: $syncedText, ')
          ..write('plainText: $plainText, ')
          ..write('instrumental: $instrumental, ')
          ..write('remoteDurationMs: $remoteDurationMs, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsPinsTable extends LyricsPins
    with TableInfo<$LyricsPinsTable, LyricsPinRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsPinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta = const VerificationMeta(
    'trackKey',
  );
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
    'track_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedTextMeta = const VerificationMeta(
    'syncedText',
  );
  @override
  late final GeneratedColumn<String> syncedText = GeneratedColumn<String>(
    'synced_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _instrumentalMeta = const VerificationMeta(
    'instrumental',
  );
  @override
  late final GeneratedColumn<bool> instrumental = GeneratedColumn<bool>(
    'instrumental',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("instrumental" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _remoteDurationMsMeta = const VerificationMeta(
    'remoteDurationMs',
  );
  @override
  late final GeneratedColumn<int> remoteDurationMs = GeneratedColumn<int>(
    'remote_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<int> pinnedAt = GeneratedColumn<int>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackKey,
    providerId,
    mode,
    remoteId,
    syncedText,
    plainText,
    instrumental,
    remoteDurationMs,
    pinnedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_pins';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsPinRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(
        _trackKeyMeta,
        trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('synced_text')) {
      context.handle(
        _syncedTextMeta,
        syncedText.isAcceptableOrUnknown(data['synced_text']!, _syncedTextMeta),
      );
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    }
    if (data.containsKey('instrumental')) {
      context.handle(
        _instrumentalMeta,
        instrumental.isAcceptableOrUnknown(
          data['instrumental']!,
          _instrumentalMeta,
        ),
      );
    }
    if (data.containsKey('remote_duration_ms')) {
      context.handle(
        _remoteDurationMsMeta,
        remoteDurationMs.isAcceptableOrUnknown(
          data['remote_duration_ms']!,
          _remoteDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  LyricsPinRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsPinRow(
      trackKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_key'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      syncedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_text'],
      ),
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      ),
      instrumental: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}instrumental'],
      )!,
      remoteDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_duration_ms'],
      ),
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $LyricsPinsTable createAlias(String alias) {
    return $LyricsPinsTable(attachedDatabase, alias);
  }
}

class LyricsPinRow extends DataClass implements Insertable<LyricsPinRow> {
  final String trackKey;
  final String? providerId;

  /// The lyrics choice: `local`, `online` or `off`; null = auto.
  final String? mode;

  /// Null = no pick stored.
  final String? remoteId;
  final String? syncedText;
  final String? plainText;
  final bool instrumental;
  final int? remoteDurationMs;
  final int pinnedAt;
  const LyricsPinRow({
    required this.trackKey,
    this.providerId,
    this.mode,
    this.remoteId,
    this.syncedText,
    this.plainText,
    required this.instrumental,
    this.remoteDurationMs,
    required this.pinnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || syncedText != null) {
      map['synced_text'] = Variable<String>(syncedText);
    }
    if (!nullToAbsent || plainText != null) {
      map['plain_text'] = Variable<String>(plainText);
    }
    map['instrumental'] = Variable<bool>(instrumental);
    if (!nullToAbsent || remoteDurationMs != null) {
      map['remote_duration_ms'] = Variable<int>(remoteDurationMs);
    }
    map['pinned_at'] = Variable<int>(pinnedAt);
    return map;
  }

  LyricsPinsCompanion toCompanion(bool nullToAbsent) {
    return LyricsPinsCompanion(
      trackKey: Value(trackKey),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      syncedText: syncedText == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedText),
      plainText: plainText == null && nullToAbsent
          ? const Value.absent()
          : Value(plainText),
      instrumental: Value(instrumental),
      remoteDurationMs: remoteDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteDurationMs),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory LyricsPinRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsPinRow(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      mode: serializer.fromJson<String?>(json['mode']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      syncedText: serializer.fromJson<String?>(json['syncedText']),
      plainText: serializer.fromJson<String?>(json['plainText']),
      instrumental: serializer.fromJson<bool>(json['instrumental']),
      remoteDurationMs: serializer.fromJson<int?>(json['remoteDurationMs']),
      pinnedAt: serializer.fromJson<int>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'providerId': serializer.toJson<String?>(providerId),
      'mode': serializer.toJson<String?>(mode),
      'remoteId': serializer.toJson<String?>(remoteId),
      'syncedText': serializer.toJson<String?>(syncedText),
      'plainText': serializer.toJson<String?>(plainText),
      'instrumental': serializer.toJson<bool>(instrumental),
      'remoteDurationMs': serializer.toJson<int?>(remoteDurationMs),
      'pinnedAt': serializer.toJson<int>(pinnedAt),
    };
  }

  LyricsPinRow copyWith({
    String? trackKey,
    Value<String?> providerId = const Value.absent(),
    Value<String?> mode = const Value.absent(),
    Value<String?> remoteId = const Value.absent(),
    Value<String?> syncedText = const Value.absent(),
    Value<String?> plainText = const Value.absent(),
    bool? instrumental,
    Value<int?> remoteDurationMs = const Value.absent(),
    int? pinnedAt,
  }) => LyricsPinRow(
    trackKey: trackKey ?? this.trackKey,
    providerId: providerId.present ? providerId.value : this.providerId,
    mode: mode.present ? mode.value : this.mode,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    syncedText: syncedText.present ? syncedText.value : this.syncedText,
    plainText: plainText.present ? plainText.value : this.plainText,
    instrumental: instrumental ?? this.instrumental,
    remoteDurationMs: remoteDurationMs.present
        ? remoteDurationMs.value
        : this.remoteDurationMs,
    pinnedAt: pinnedAt ?? this.pinnedAt,
  );
  LyricsPinRow copyWithCompanion(LyricsPinsCompanion data) {
    return LyricsPinRow(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      mode: data.mode.present ? data.mode.value : this.mode,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      syncedText: data.syncedText.present
          ? data.syncedText.value
          : this.syncedText,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      instrumental: data.instrumental.present
          ? data.instrumental.value
          : this.instrumental,
      remoteDurationMs: data.remoteDurationMs.present
          ? data.remoteDurationMs.value
          : this.remoteDurationMs,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsPinRow(')
          ..write('trackKey: $trackKey, ')
          ..write('providerId: $providerId, ')
          ..write('mode: $mode, ')
          ..write('remoteId: $remoteId, ')
          ..write('syncedText: $syncedText, ')
          ..write('plainText: $plainText, ')
          ..write('instrumental: $instrumental, ')
          ..write('remoteDurationMs: $remoteDurationMs, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackKey,
    providerId,
    mode,
    remoteId,
    syncedText,
    plainText,
    instrumental,
    remoteDurationMs,
    pinnedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsPinRow &&
          other.trackKey == this.trackKey &&
          other.providerId == this.providerId &&
          other.mode == this.mode &&
          other.remoteId == this.remoteId &&
          other.syncedText == this.syncedText &&
          other.plainText == this.plainText &&
          other.instrumental == this.instrumental &&
          other.remoteDurationMs == this.remoteDurationMs &&
          other.pinnedAt == this.pinnedAt);
}

class LyricsPinsCompanion extends UpdateCompanion<LyricsPinRow> {
  final Value<String> trackKey;
  final Value<String?> providerId;
  final Value<String?> mode;
  final Value<String?> remoteId;
  final Value<String?> syncedText;
  final Value<String?> plainText;
  final Value<bool> instrumental;
  final Value<int?> remoteDurationMs;
  final Value<int> pinnedAt;
  final Value<int> rowid;
  const LyricsPinsCompanion({
    this.trackKey = const Value.absent(),
    this.providerId = const Value.absent(),
    this.mode = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.syncedText = const Value.absent(),
    this.plainText = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.remoteDurationMs = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricsPinsCompanion.insert({
    required String trackKey,
    this.providerId = const Value.absent(),
    this.mode = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.syncedText = const Value.absent(),
    this.plainText = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.remoteDurationMs = const Value.absent(),
    required int pinnedAt,
    this.rowid = const Value.absent(),
  }) : trackKey = Value(trackKey),
       pinnedAt = Value(pinnedAt);
  static Insertable<LyricsPinRow> custom({
    Expression<String>? trackKey,
    Expression<String>? providerId,
    Expression<String>? mode,
    Expression<String>? remoteId,
    Expression<String>? syncedText,
    Expression<String>? plainText,
    Expression<bool>? instrumental,
    Expression<int>? remoteDurationMs,
    Expression<int>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (providerId != null) 'provider_id': providerId,
      if (mode != null) 'mode': mode,
      if (remoteId != null) 'remote_id': remoteId,
      if (syncedText != null) 'synced_text': syncedText,
      if (plainText != null) 'plain_text': plainText,
      if (instrumental != null) 'instrumental': instrumental,
      if (remoteDurationMs != null) 'remote_duration_ms': remoteDurationMs,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricsPinsCompanion copyWith({
    Value<String>? trackKey,
    Value<String?>? providerId,
    Value<String?>? mode,
    Value<String?>? remoteId,
    Value<String?>? syncedText,
    Value<String?>? plainText,
    Value<bool>? instrumental,
    Value<int?>? remoteDurationMs,
    Value<int>? pinnedAt,
    Value<int>? rowid,
  }) {
    return LyricsPinsCompanion(
      trackKey: trackKey ?? this.trackKey,
      providerId: providerId ?? this.providerId,
      mode: mode ?? this.mode,
      remoteId: remoteId ?? this.remoteId,
      syncedText: syncedText ?? this.syncedText,
      plainText: plainText ?? this.plainText,
      instrumental: instrumental ?? this.instrumental,
      remoteDurationMs: remoteDurationMs ?? this.remoteDurationMs,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (syncedText.present) {
      map['synced_text'] = Variable<String>(syncedText.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (instrumental.present) {
      map['instrumental'] = Variable<bool>(instrumental.value);
    }
    if (remoteDurationMs.present) {
      map['remote_duration_ms'] = Variable<int>(remoteDurationMs.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<int>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsPinsCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('providerId: $providerId, ')
          ..write('mode: $mode, ')
          ..write('remoteId: $remoteId, ')
          ..write('syncedText: $syncedText, ')
          ..write('plainText: $plainText, ')
          ..write('instrumental: $instrumental, ')
          ..write('remoteDurationMs: $remoteDurationMs, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnlineLyricsRejectsTable extends OnlineLyricsRejects
    with TableInfo<$OnlineLyricsRejectsTable, OnlineLyricsRejectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnlineLyricsRejectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rejectedAtMeta = const VerificationMeta(
    'rejectedAt',
  );
  @override
  late final GeneratedColumn<int> rejectedAt = GeneratedColumn<int>(
    'rejected_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    providerId,
    remoteId,
    contentHash,
    rejectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'online_lyrics_rejects';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnlineLyricsRejectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('rejected_at')) {
      context.handle(
        _rejectedAtMeta,
        rejectedAt.isAcceptableOrUnknown(data['rejected_at']!, _rejectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_rejectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey, providerId, remoteId};
  @override
  OnlineLyricsRejectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnlineLyricsRejectRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      rejectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected_at'],
      )!,
    );
  }

  @override
  $OnlineLyricsRejectsTable createAlias(String alias) {
    return $OnlineLyricsRejectsTable(attachedDatabase, alias);
  }
}

class OnlineLyricsRejectRow extends DataClass
    implements Insertable<OnlineLyricsRejectRow> {
  final String cacheKey;
  final String providerId;
  final String remoteId;

  /// `lyricsContentHash` of the rejected text; null for older rejects.
  final String? contentHash;
  final int rejectedAt;
  const OnlineLyricsRejectRow({
    required this.cacheKey,
    required this.providerId,
    required this.remoteId,
    this.contentHash,
    required this.rejectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['provider_id'] = Variable<String>(providerId);
    map['remote_id'] = Variable<String>(remoteId);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['rejected_at'] = Variable<int>(rejectedAt);
    return map;
  }

  OnlineLyricsRejectsCompanion toCompanion(bool nullToAbsent) {
    return OnlineLyricsRejectsCompanion(
      cacheKey: Value(cacheKey),
      providerId: Value(providerId),
      remoteId: Value(remoteId),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      rejectedAt: Value(rejectedAt),
    );
  }

  factory OnlineLyricsRejectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnlineLyricsRejectRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      providerId: serializer.fromJson<String>(json['providerId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      rejectedAt: serializer.fromJson<int>(json['rejectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'providerId': serializer.toJson<String>(providerId),
      'remoteId': serializer.toJson<String>(remoteId),
      'contentHash': serializer.toJson<String?>(contentHash),
      'rejectedAt': serializer.toJson<int>(rejectedAt),
    };
  }

  OnlineLyricsRejectRow copyWith({
    String? cacheKey,
    String? providerId,
    String? remoteId,
    Value<String?> contentHash = const Value.absent(),
    int? rejectedAt,
  }) => OnlineLyricsRejectRow(
    cacheKey: cacheKey ?? this.cacheKey,
    providerId: providerId ?? this.providerId,
    remoteId: remoteId ?? this.remoteId,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    rejectedAt: rejectedAt ?? this.rejectedAt,
  );
  OnlineLyricsRejectRow copyWithCompanion(OnlineLyricsRejectsCompanion data) {
    return OnlineLyricsRejectRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      rejectedAt: data.rejectedAt.present
          ? data.rejectedAt.value
          : this.rejectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnlineLyricsRejectRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('providerId: $providerId, ')
          ..write('remoteId: $remoteId, ')
          ..write('contentHash: $contentHash, ')
          ..write('rejectedAt: $rejectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cacheKey, providerId, remoteId, contentHash, rejectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnlineLyricsRejectRow &&
          other.cacheKey == this.cacheKey &&
          other.providerId == this.providerId &&
          other.remoteId == this.remoteId &&
          other.contentHash == this.contentHash &&
          other.rejectedAt == this.rejectedAt);
}

class OnlineLyricsRejectsCompanion
    extends UpdateCompanion<OnlineLyricsRejectRow> {
  final Value<String> cacheKey;
  final Value<String> providerId;
  final Value<String> remoteId;
  final Value<String?> contentHash;
  final Value<int> rejectedAt;
  final Value<int> rowid;
  const OnlineLyricsRejectsCompanion({
    this.cacheKey = const Value.absent(),
    this.providerId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.rejectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnlineLyricsRejectsCompanion.insert({
    required String cacheKey,
    required String providerId,
    required String remoteId,
    this.contentHash = const Value.absent(),
    required int rejectedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       providerId = Value(providerId),
       remoteId = Value(remoteId),
       rejectedAt = Value(rejectedAt);
  static Insertable<OnlineLyricsRejectRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? providerId,
    Expression<String>? remoteId,
    Expression<String>? contentHash,
    Expression<int>? rejectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (providerId != null) 'provider_id': providerId,
      if (remoteId != null) 'remote_id': remoteId,
      if (contentHash != null) 'content_hash': contentHash,
      if (rejectedAt != null) 'rejected_at': rejectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnlineLyricsRejectsCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? providerId,
    Value<String>? remoteId,
    Value<String?>? contentHash,
    Value<int>? rejectedAt,
    Value<int>? rowid,
  }) {
    return OnlineLyricsRejectsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      providerId: providerId ?? this.providerId,
      remoteId: remoteId ?? this.remoteId,
      contentHash: contentHash ?? this.contentHash,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (rejectedAt.present) {
      map['rejected_at'] = Variable<int>(rejectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnlineLyricsRejectsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('providerId: $providerId, ')
          ..write('remoteId: $remoteId, ')
          ..write('contentHash: $contentHash, ')
          ..write('rejectedAt: $rejectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $PlaysTable plays = $PlaysTable(this);
  late final $PlayStatsTable playStats = $PlayStatsTable(this);
  late final Trigger playsStatsInsert = Trigger(
    'CREATE TRIGGER plays_stats_insert AFTER INSERT ON plays BEGIN INSERT INTO play_stats (path, play_count, first_played_at, last_played_at) VALUES (new.path, 1, new.played_at, new.played_at) ON CONFLICT (path) DO UPDATE SET play_count = play_count + 1, first_played_at = min(first_played_at, excluded.first_played_at), last_played_at = max(last_played_at, excluded.last_played_at);END',
    'plays_stats_insert',
  );
  late final Trigger playsStatsDelete = Trigger(
    'CREATE TRIGGER plays_stats_delete AFTER DELETE ON plays BEGIN UPDATE play_stats SET play_count = play_count - 1, first_played_at = coalesce((SELECT min(played_at) FROM plays WHERE path = old.path), first_played_at), last_played_at = coalesce((SELECT max(played_at) FROM plays WHERE path = old.path), last_played_at) WHERE path = old.path;DELETE FROM play_stats WHERE path = old.path AND play_count <= 0;END',
    'plays_stats_delete',
  );
  late final Trigger playsStatsUpdate = Trigger(
    'CREATE TRIGGER plays_stats_update AFTER UPDATE OF path, played_at ON plays WHEN old.path IS NOT new.path OR old.played_at IS NOT new.played_at BEGIN UPDATE play_stats SET play_count = play_count - 1, first_played_at = coalesce((SELECT min(played_at) FROM plays WHERE path = old.path), first_played_at), last_played_at = coalesce((SELECT max(played_at) FROM plays WHERE path = old.path), last_played_at) WHERE path = old.path;DELETE FROM play_stats WHERE path = old.path AND play_count <= 0;INSERT INTO play_stats (path, play_count, first_played_at, last_played_at) VALUES (new.path, 1, new.played_at, new.played_at) ON CONFLICT (path) DO UPDATE SET play_count = play_count + 1, first_played_at = min(first_played_at, excluded.first_played_at), last_played_at = max(last_played_at, excluded.last_played_at);END',
    'plays_stats_update',
  );
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(
    this,
  );
  late final Index playsPathPlayed = Index(
    'plays_path_played',
    'CREATE INDEX plays_path_played ON plays (path, played_at)',
  );
  late final Index playsPlayedAt = Index(
    'plays_played_at',
    'CREATE INDEX plays_played_at ON plays (played_at, path)',
  );
  late final Index playlistsFavoritesUnique = Index(
    'playlists_favorites_unique',
    'CREATE UNIQUE INDEX playlists_favorites_unique ON playlists (kind) WHERE kind = \'favorites\'',
  );
  late final Index playlistEntriesOrder = Index(
    'playlist_entries_order',
    'CREATE INDEX playlist_entries_order ON playlist_entries (playlist_id, position)',
  );
  late final $LibraryRootsTable libraryRoots = $LibraryRootsTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final TrackSearch trackSearch = TrackSearch(this);
  late final Trigger tracksSearchInsert = Trigger(
    'CREATE TRIGGER tracks_search_insert AFTER INSERT ON tracks BEGIN INSERT INTO track_search ("rowid", title_sort, artist_search, album_search, album_artist_search, genre_search) VALUES (new.id, new.title_sort, new.artist_search, new.album_search, new.album_artist_search, new.genre_search);END',
    'tracks_search_insert',
  );
  late final Trigger tracksSearchDelete = Trigger(
    'CREATE TRIGGER tracks_search_delete AFTER DELETE ON tracks BEGIN INSERT INTO track_search (track_search, "rowid", title_sort, artist_search, album_search, album_artist_search, genre_search) VALUES (\'delete\', old.id, old.title_sort, old.artist_search, old.album_search, old.album_artist_search, old.genre_search);END',
    'tracks_search_delete',
  );
  late final Trigger tracksSearchUpdate = Trigger(
    'CREATE TRIGGER tracks_search_update AFTER UPDATE OF title_sort, artist_search, album_search, album_artist_search, genre_search ON tracks WHEN old.title_sort IS NOT new.title_sort OR old.artist_search IS NOT new.artist_search OR old.album_search IS NOT new.album_search OR old.album_artist_search IS NOT new.album_artist_search OR old.genre_search IS NOT new.genre_search BEGIN INSERT INTO track_search (track_search, "rowid", title_sort, artist_search, album_search, album_artist_search, genre_search) VALUES (\'delete\', old.id, old.title_sort, old.artist_search, old.album_search, old.album_artist_search, old.genre_search);INSERT INTO track_search ("rowid", title_sort, artist_search, album_search, album_artist_search, genre_search) VALUES (new.id, new.title_sort, new.artist_search, new.album_search, new.album_artist_search, new.genre_search);END',
    'tracks_search_update',
  );
  late final $TrackArtistsTable trackArtists = $TrackArtistsTable(this);
  late final $CoverColorsTable coverColors = $CoverColorsTable(this);
  late final $ExcludedFoldersTable excludedFolders = $ExcludedFoldersTable(
    this,
  );
  late final Index tracksRoot = Index(
    'tracks_root',
    'CREATE INDEX tracks_root ON tracks (root_id)',
  );
  late final Index tracksTitleSort = Index(
    'tracks_title_sort',
    'CREATE INDEX tracks_title_sort ON tracks (title_sort, id)',
  );
  late final Index tracksAlbumKey = Index(
    'tracks_album_key',
    'CREATE INDEX tracks_album_key ON tracks (album_artist_key, album_title_key)',
  );
  late final Index tracksKeysVersion = Index(
    'tracks_keys_version',
    'CREATE INDEX tracks_keys_version ON tracks (keys_version)',
  );
  late final Index tracksLanguage = Index(
    'tracks_language',
    'CREATE INDEX tracks_language ON tracks (language)',
  );
  late final Index tracksAddedAt = Index(
    'tracks_added_at',
    'CREATE INDEX tracks_added_at ON tracks (added_at)',
  );
  late final Index trackArtistsTrack = Index(
    'track_artists_track',
    'CREATE INDEX track_artists_track ON track_artists (track_id)',
  );
  late final $LyricTranslationsTable lyricTranslations =
      $LyricTranslationsTable(this);
  late final $LyricTranslationPrefsTable lyricTranslationPrefs =
      $LyricTranslationPrefsTable(this);
  late final $OnlineLyricsTable onlineLyrics = $OnlineLyricsTable(this);
  late final $LyricsPinsTable lyricsPins = $LyricsPinsTable(this);
  late final $OnlineLyricsRejectsTable onlineLyricsRejects =
      $OnlineLyricsRejectsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    plays,
    playStats,
    playsStatsInsert,
    playsStatsDelete,
    playsStatsUpdate,
    playlists,
    playlistEntries,
    playsPathPlayed,
    playsPlayedAt,
    playlistsFavoritesUnique,
    playlistEntriesOrder,
    libraryRoots,
    tracks,
    trackSearch,
    tracksSearchInsert,
    tracksSearchDelete,
    tracksSearchUpdate,
    trackArtists,
    coverColors,
    excludedFolders,
    tracksRoot,
    tracksTitleSort,
    tracksAlbumKey,
    tracksKeysVersion,
    tracksLanguage,
    tracksAddedAt,
    trackArtistsTrack,
    lyricTranslations,
    lyricTranslationPrefs,
    onlineLyrics,
    lyricsPins,
    onlineLyricsRejects,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plays',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('play_stats', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plays',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('play_stats', kind: UpdateKind.update),
        TableUpdate('play_stats', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plays',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [
        TableUpdate('play_stats', kind: UpdateKind.update),
        TableUpdate('play_stats', kind: UpdateKind.delete),
        TableUpdate('play_stats', kind: UpdateKind.insert),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_roots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('track_search', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_search', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('track_search', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_artists', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PlaysTableCreateCompanionBuilder = PlaysCompanion Function({
  Value<int> id,
  required String path,
  required int playedAt,
  Value<int?> listenedMs,
});
typedef $$PlaysTableUpdateCompanionBuilder = PlaysCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<int> playedAt,
  Value<int?> listenedMs,
});

class $$PlaysTableFilterComposer
    extends Composer<_$LibraryDatabase, $PlaysTable> {
  $$PlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaysTableOrderingComposer
    extends Composer<_$LibraryDatabase, $PlaysTable> {
  $$PlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaysTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $PlaysTable> {
  $$PlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );
}

class $$PlaysTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $PlaysTable,
          Play,
          $$PlaysTableFilterComposer,
          $$PlaysTableOrderingComposer,
          $$PlaysTableAnnotationComposer,
          $$PlaysTableCreateCompanionBuilder,
          $$PlaysTableUpdateCompanionBuilder,
          (Play, BaseReferences<_$LibraryDatabase, $PlaysTable, Play>),
          Play,
          PrefetchHooks Function()
        > {
  $$PlaysTableTableManager(_$LibraryDatabase db, $PlaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> playedAt = const Value.absent(),
                Value<int?> listenedMs = const Value.absent(),
              }) => PlaysCompanion(
                id: id,
                path: path,
                playedAt: playedAt,
                listenedMs: listenedMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int playedAt,
                Value<int?> listenedMs = const Value.absent(),
              }) => PlaysCompanion.insert(
                id: id,
                path: path,
                playedAt: playedAt,
                listenedMs: listenedMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaysTable, Play>(table),
                  BaseReferences<_$LibraryDatabase, $PlaysTable, Play>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $PlaysTable,
      Play,
      $$PlaysTableFilterComposer,
      $$PlaysTableOrderingComposer,
      $$PlaysTableAnnotationComposer,
      $$PlaysTableCreateCompanionBuilder,
      $$PlaysTableUpdateCompanionBuilder,
      (Play, BaseReferences<_$LibraryDatabase, $PlaysTable, Play>),
      Play,
      PrefetchHooks Function()
    >;
typedef $$PlayStatsTableCreateCompanionBuilder = PlayStatsCompanion Function({
  required String path,
  required int playCount,
  required int firstPlayedAt,
  required int lastPlayedAt,
  Value<int> rowid,
});
typedef $$PlayStatsTableUpdateCompanionBuilder = PlayStatsCompanion Function({
  Value<String> path,
  Value<int> playCount,
  Value<int> firstPlayedAt,
  Value<int> lastPlayedAt,
  Value<int> rowid,
});

class $$PlayStatsTableFilterComposer
    extends Composer<_$LibraryDatabase, $PlayStatsTable> {
  $$PlayStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstPlayedAt => $composableBuilder(
    column: $table.firstPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayStatsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $PlayStatsTable> {
  $$PlayStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstPlayedAt => $composableBuilder(
    column: $table.firstPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayStatsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $PlayStatsTable> {
  $$PlayStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get firstPlayedAt => $composableBuilder(
    column: $table.firstPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$PlayStatsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $PlayStatsTable,
          PlayStat,
          $$PlayStatsTableFilterComposer,
          $$PlayStatsTableOrderingComposer,
          $$PlayStatsTableAnnotationComposer,
          $$PlayStatsTableCreateCompanionBuilder,
          $$PlayStatsTableUpdateCompanionBuilder,
          (
            PlayStat,
            BaseReferences<_$LibraryDatabase, $PlayStatsTable, PlayStat>,
          ),
          PlayStat,
          PrefetchHooks Function()
        > {
  $$PlayStatsTableTableManager(_$LibraryDatabase db, $PlayStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> firstPlayedAt = const Value.absent(),
                Value<int> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayStatsCompanion(
                path: path,
                playCount: playCount,
                firstPlayedAt: firstPlayedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int playCount,
                required int firstPlayedAt,
                required int lastPlayedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlayStatsCompanion.insert(
                path: path,
                playCount: playCount,
                firstPlayedAt: firstPlayedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayStatsTable, PlayStat>(table),
                  BaseReferences<_$LibraryDatabase, $PlayStatsTable, PlayStat>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $PlayStatsTable,
      PlayStat,
      $$PlayStatsTableFilterComposer,
      $$PlayStatsTableOrderingComposer,
      $$PlayStatsTableAnnotationComposer,
      $$PlayStatsTableCreateCompanionBuilder,
      $$PlayStatsTableUpdateCompanionBuilder,
      (PlayStat, BaseReferences<_$LibraryDatabase, $PlayStatsTable, PlayStat>),
      PlayStat,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required int createdAt,
  Value<String?> kind,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> createdAt,
  Value<String?> kind,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$LibraryDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntry>>
  _playlistEntriesRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playlistEntries,
        aliasName: 'playlists__id__playlist_entries__playlist_id',
      );

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager = $$PlaylistEntriesTableTableManager(
      $_db,
      $_db.playlistEntries,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$LibraryDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistEntriesRefs(
    Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f,
  ) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  Expression<T> playlistEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistEntriesRefs})
        > {
  $$PlaylistsTableTableManager(_$LibraryDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> kind = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                kind: kind,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int createdAt,
                Value<String?> kind = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                kind: kind,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistEntriesRefs) db.playlistEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistEntriesRefs)
                    await $_getPrefetchedData<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistEntry
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistEntriesRefs})
    >;
typedef $$PlaylistEntriesTableCreateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      required int playlistId,
      required String path,
      required int position,
    });
typedef $$PlaylistEntriesTableUpdateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> path,
      Value<int> position,
    });

final class $$PlaylistEntriesTableReferences
    extends
        BaseReferences<
          _$LibraryDatabase,
          $PlaylistEntriesTable,
          PlaylistEntry
        > {
  $$PlaylistEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$LibraryDatabase db) =>
      db.playlists.createAlias('playlist_entries__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$LibraryDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$LibraryDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $PlaylistEntriesTable,
          PlaylistEntry,
          $$PlaylistEntriesTableFilterComposer,
          $$PlaylistEntriesTableOrderingComposer,
          $$PlaylistEntriesTableAnnotationComposer,
          $$PlaylistEntriesTableCreateCompanionBuilder,
          $$PlaylistEntriesTableUpdateCompanionBuilder,
          (PlaylistEntry, $$PlaylistEntriesTableReferences),
          PlaylistEntry,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistEntriesTableTableManager(
    _$LibraryDatabase db,
    $PlaylistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => PlaylistEntriesCompanion(
                id: id,
                playlistId: playlistId,
                path: path,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String path,
                required int position,
              }) => PlaylistEntriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                path: path,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistEntriesTable, PlaylistEntry>(table),
                  $$PlaylistEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $PlaylistEntriesTable,
      PlaylistEntry,
      $$PlaylistEntriesTableFilterComposer,
      $$PlaylistEntriesTableOrderingComposer,
      $$PlaylistEntriesTableAnnotationComposer,
      $$PlaylistEntriesTableCreateCompanionBuilder,
      $$PlaylistEntriesTableUpdateCompanionBuilder,
      (PlaylistEntry, $$PlaylistEntriesTableReferences),
      PlaylistEntry,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$LibraryRootsTableCreateCompanionBuilder =
    LibraryRootsCompanion Function({
      Value<int> id,
      required String path,
      required int addedAt,
      Value<int?> lastScanAt,
    });
typedef $$LibraryRootsTableUpdateCompanionBuilder =
    LibraryRootsCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<int> addedAt,
      Value<int?> lastScanAt,
    });

final class $$LibraryRootsTableReferences
    extends BaseReferences<_$LibraryDatabase, $LibraryRootsTable, LibraryRoot> {
  $$LibraryRootsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$LibraryDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'library_roots__id__tracks__root_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.rootId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryRootsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.rootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryRootsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryRootsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.rootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryRootsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryRootsTable,
          LibraryRoot,
          $$LibraryRootsTableFilterComposer,
          $$LibraryRootsTableOrderingComposer,
          $$LibraryRootsTableAnnotationComposer,
          $$LibraryRootsTableCreateCompanionBuilder,
          $$LibraryRootsTableUpdateCompanionBuilder,
          (LibraryRoot, $$LibraryRootsTableReferences),
          LibraryRoot,
          PrefetchHooks Function({bool tracksRefs})
        > {
  $$LibraryRootsTableTableManager(
    _$LibraryDatabase db,
    $LibraryRootsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int?> lastScanAt = const Value.absent(),
              }) => LibraryRootsCompanion(
                id: id,
                path: path,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int addedAt,
                Value<int?> lastScanAt = const Value.absent(),
              }) => LibraryRootsCompanion.insert(
                id: id,
                path: path,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryRootsTable, LibraryRoot>(table),
                  $$LibraryRootsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<
                      LibraryRoot,
                      $LibraryRootsTable,
                      Track
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryRootsTableReferences
                          ._tracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryRootsTableReferences(
                            db,
                            table,
                            p0,
                          ).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.rootId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryRootsTable,
      LibraryRoot,
      $$LibraryRootsTableFilterComposer,
      $$LibraryRootsTableOrderingComposer,
      $$LibraryRootsTableAnnotationComposer,
      $$LibraryRootsTableCreateCompanionBuilder,
      $$LibraryRootsTableUpdateCompanionBuilder,
      (LibraryRoot, $$LibraryRootsTableReferences),
      LibraryRoot,
      PrefetchHooks Function({bool tracksRefs})
    >;
typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required int rootId,
  required String path,
  required int mtimeMs,
  required int sizeBytes,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumArtist,
  Value<int?> trackNo,
  Value<int?> trackTotal,
  Value<int?> discNo,
  Value<int?> discTotal,
  Value<int?> year,
  Value<String?> genre,
  Value<String?> composer,
  Value<String?> comment,
  Value<String?> language,
  Value<int?> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<int?> bitDepth,
  Value<int?> channels,
  required int addedAt,
  required int updatedAt,
  Value<String?> scanError,
  Value<String?> coverKey,
  Value<int> coverScanVersion,
  Value<String?> albumArtistKey,
  Value<String?> albumTitleKey,
  Value<String?> albumDisplayArtist,
  Value<String> titleSort,
  Value<String?> artistSort,
  Value<String?> albumSort,
  Value<String?> artistSearch,
  Value<String?> albumSearch,
  Value<String?> albumArtistSearch,
  Value<String?> genreSearch,
  Value<int> keysVersion,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<int> rootId,
  Value<String> path,
  Value<int> mtimeMs,
  Value<int> sizeBytes,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumArtist,
  Value<int?> trackNo,
  Value<int?> trackTotal,
  Value<int?> discNo,
  Value<int?> discTotal,
  Value<int?> year,
  Value<String?> genre,
  Value<String?> composer,
  Value<String?> comment,
  Value<String?> language,
  Value<int?> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<int?> bitDepth,
  Value<int?> channels,
  Value<int> addedAt,
  Value<int> updatedAt,
  Value<String?> scanError,
  Value<String?> coverKey,
  Value<int> coverScanVersion,
  Value<String?> albumArtistKey,
  Value<String?> albumTitleKey,
  Value<String?> albumDisplayArtist,
  Value<String> titleSort,
  Value<String?> artistSort,
  Value<String?> albumSort,
  Value<String?> artistSearch,
  Value<String?> albumSearch,
  Value<String?> albumArtistSearch,
  Value<String?> genreSearch,
  Value<int> keysVersion,
});

final class $$TracksTableReferences
    extends BaseReferences<_$LibraryDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryRootsTable _rootIdTable(_$LibraryDatabase db) =>
      db.libraryRoots.createAlias('tracks__root_id__library_roots__id');

  $$LibraryRootsTableProcessedTableManager get rootId {
    final $_column = $_itemColumn<int>('root_id')!;

    final manager = $$LibraryRootsTableTableManager(
      $_db,
      $_db.libraryRoots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rootIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TrackArtistsTable, List<TrackArtist>>
  _trackArtistsRefsTable(_$LibraryDatabase db) => MultiTypedResultKey.fromTable(
    db.trackArtists,
    aliasName: 'tracks__id__track_artists__track_id',
  );

  $$TrackArtistsTableProcessedTableManager get trackArtistsRefs {
    final manager = $$TrackArtistsTableTableManager(
      $_db,
      $_db.trackArtists,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackArtistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackTotal => $composableBuilder(
    column: $table.trackTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNo => $composableBuilder(
    column: $table.discNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discTotal => $composableBuilder(
    column: $table.discTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanError => $composableBuilder(
    column: $table.scanError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverScanVersion => $composableBuilder(
    column: $table.coverScanVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtistKey => $composableBuilder(
    column: $table.albumArtistKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumTitleKey => $composableBuilder(
    column: $table.albumTitleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumDisplayArtist => $composableBuilder(
    column: $table.albumDisplayArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleSort => $composableBuilder(
    column: $table.titleSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistSort => $composableBuilder(
    column: $table.artistSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumSort => $composableBuilder(
    column: $table.albumSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keysVersion => $composableBuilder(
    column: $table.keysVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryRootsTableFilterComposer get rootId {
    final $$LibraryRootsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.libraryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryRootsTableFilterComposer(
            $db: $db,
            $table: $db.libraryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> trackArtistsRefs(
    Expression<bool> Function($$TrackArtistsTableFilterComposer f) f,
  ) {
    final $$TrackArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackArtists,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackArtistsTableFilterComposer(
            $db: $db,
            $table: $db.trackArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackTotal => $composableBuilder(
    column: $table.trackTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNo => $composableBuilder(
    column: $table.discNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discTotal => $composableBuilder(
    column: $table.discTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanError => $composableBuilder(
    column: $table.scanError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverScanVersion => $composableBuilder(
    column: $table.coverScanVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtistKey => $composableBuilder(
    column: $table.albumArtistKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumTitleKey => $composableBuilder(
    column: $table.albumTitleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumDisplayArtist => $composableBuilder(
    column: $table.albumDisplayArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleSort => $composableBuilder(
    column: $table.titleSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistSort => $composableBuilder(
    column: $table.artistSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumSort => $composableBuilder(
    column: $table.albumSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keysVersion => $composableBuilder(
    column: $table.keysVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryRootsTableOrderingComposer get rootId {
    final $$LibraryRootsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.libraryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryRootsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TracksTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNo =>
      $composableBuilder(column: $table.trackNo, builder: (column) => column);

  GeneratedColumn<int> get trackTotal => $composableBuilder(
    column: $table.trackTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNo =>
      $composableBuilder(column: $table.discNo, builder: (column) => column);

  GeneratedColumn<int> get discTotal =>
      $composableBuilder(column: $table.discTotal, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get composer =>
      $composableBuilder(column: $table.composer, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitDepth =>
      $composableBuilder(column: $table.bitDepth, builder: (column) => column);

  GeneratedColumn<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get scanError =>
      $composableBuilder(column: $table.scanError, builder: (column) => column);

  GeneratedColumn<String> get coverKey =>
      $composableBuilder(column: $table.coverKey, builder: (column) => column);

  GeneratedColumn<int> get coverScanVersion => $composableBuilder(
    column: $table.coverScanVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumArtistKey => $composableBuilder(
    column: $table.albumArtistKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumTitleKey => $composableBuilder(
    column: $table.albumTitleKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumDisplayArtist => $composableBuilder(
    column: $table.albumDisplayArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleSort =>
      $composableBuilder(column: $table.titleSort, builder: (column) => column);

  GeneratedColumn<String> get artistSort => $composableBuilder(
    column: $table.artistSort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumSort =>
      $composableBuilder(column: $table.albumSort, builder: (column) => column);

  GeneratedColumn<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get keysVersion => $composableBuilder(
    column: $table.keysVersion,
    builder: (column) => column,
  );

  $$LibraryRootsTableAnnotationComposer get rootId {
    final $$LibraryRootsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootId,
      referencedTable: $db.libraryRoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryRootsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> trackArtistsRefs<T extends Object>(
    Expression<T> Function($$TrackArtistsTableAnnotationComposer a) f,
  ) {
    final $$TrackArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackArtists,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({bool rootId, bool trackArtistsRefs})
        > {
  $$TracksTableTableManager(_$LibraryDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> rootId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<int?> trackTotal = const Value.absent(),
                Value<int?> discNo = const Value.absent(),
                Value<int?> discTotal = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> composer = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> scanError = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<int> coverScanVersion = const Value.absent(),
                Value<String?> albumArtistKey = const Value.absent(),
                Value<String?> albumTitleKey = const Value.absent(),
                Value<String?> albumDisplayArtist = const Value.absent(),
                Value<String> titleSort = const Value.absent(),
                Value<String?> artistSort = const Value.absent(),
                Value<String?> albumSort = const Value.absent(),
                Value<String?> artistSearch = const Value.absent(),
                Value<String?> albumSearch = const Value.absent(),
                Value<String?> albumArtistSearch = const Value.absent(),
                Value<String?> genreSearch = const Value.absent(),
                Value<int> keysVersion = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                rootId: rootId,
                path: path,
                mtimeMs: mtimeMs,
                sizeBytes: sizeBytes,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                trackNo: trackNo,
                trackTotal: trackTotal,
                discNo: discNo,
                discTotal: discTotal,
                year: year,
                genre: genre,
                composer: composer,
                comment: comment,
                language: language,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                channels: channels,
                addedAt: addedAt,
                updatedAt: updatedAt,
                scanError: scanError,
                coverKey: coverKey,
                coverScanVersion: coverScanVersion,
                albumArtistKey: albumArtistKey,
                albumTitleKey: albumTitleKey,
                albumDisplayArtist: albumDisplayArtist,
                titleSort: titleSort,
                artistSort: artistSort,
                albumSort: albumSort,
                artistSearch: artistSearch,
                albumSearch: albumSearch,
                albumArtistSearch: albumArtistSearch,
                genreSearch: genreSearch,
                keysVersion: keysVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int rootId,
                required String path,
                required int mtimeMs,
                required int sizeBytes,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<int?> trackTotal = const Value.absent(),
                Value<int?> discNo = const Value.absent(),
                Value<int?> discTotal = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> composer = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                required int addedAt,
                required int updatedAt,
                Value<String?> scanError = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<int> coverScanVersion = const Value.absent(),
                Value<String?> albumArtistKey = const Value.absent(),
                Value<String?> albumTitleKey = const Value.absent(),
                Value<String?> albumDisplayArtist = const Value.absent(),
                Value<String> titleSort = const Value.absent(),
                Value<String?> artistSort = const Value.absent(),
                Value<String?> albumSort = const Value.absent(),
                Value<String?> artistSearch = const Value.absent(),
                Value<String?> albumSearch = const Value.absent(),
                Value<String?> albumArtistSearch = const Value.absent(),
                Value<String?> genreSearch = const Value.absent(),
                Value<int> keysVersion = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                rootId: rootId,
                path: path,
                mtimeMs: mtimeMs,
                sizeBytes: sizeBytes,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                trackNo: trackNo,
                trackTotal: trackTotal,
                discNo: discNo,
                discTotal: discTotal,
                year: year,
                genre: genre,
                composer: composer,
                comment: comment,
                language: language,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                channels: channels,
                addedAt: addedAt,
                updatedAt: updatedAt,
                scanError: scanError,
                coverKey: coverKey,
                coverScanVersion: coverScanVersion,
                albumArtistKey: albumArtistKey,
                albumTitleKey: albumTitleKey,
                albumDisplayArtist: albumDisplayArtist,
                titleSort: titleSort,
                artistSort: artistSort,
                albumSort: albumSort,
                artistSearch: artistSearch,
                albumSearch: albumSearch,
                albumArtistSearch: albumArtistSearch,
                genreSearch: genreSearch,
                keysVersion: keysVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, Track>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rootId = false, trackArtistsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trackArtistsRefs) db.trackArtists],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (rootId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.rootId,
                        referencedTable: $$TracksTableReferences._rootIdTable(
                          db,
                        ),
                        referencedColumn: $$TracksTableReferences
                            ._rootIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trackArtistsRefs)
                    await $_getPrefetchedData<Track, $TracksTable, TrackArtist>(
                      currentTable: table,
                      referencedTable: $$TracksTableReferences
                          ._trackArtistsRefsTable(db),
                      managerFromTypedResult: (p0) => $$TracksTableReferences(
                        db,
                        table,
                        p0,
                      ).trackArtistsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.trackId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({bool rootId, bool trackArtistsRefs})
    >;
typedef $TrackSearchCreateCompanionBuilder = TrackSearchCompanion Function({
  required String titleSort,
  required String artistSearch,
  required String albumSearch,
  required String albumArtistSearch,
  required String genreSearch,
  Value<int> rowid,
});
typedef $TrackSearchUpdateCompanionBuilder = TrackSearchCompanion Function({
  Value<String> titleSort,
  Value<String> artistSearch,
  Value<String> albumSearch,
  Value<String> albumArtistSearch,
  Value<String> genreSearch,
  Value<int> rowid,
});

class $TrackSearchFilterComposer
    extends Composer<_$LibraryDatabase, TrackSearch> {
  $TrackSearchFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleSort => $composableBuilder(
    column: $table.titleSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => ColumnFilters(column),
  );
}

class $TrackSearchOrderingComposer
    extends Composer<_$LibraryDatabase, TrackSearch> {
  $TrackSearchOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleSort => $composableBuilder(
    column: $table.titleSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => ColumnOrderings(column),
  );
}

class $TrackSearchAnnotationComposer
    extends Composer<_$LibraryDatabase, TrackSearch> {
  $TrackSearchAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleSort =>
      $composableBuilder(column: $table.titleSort, builder: (column) => column);

  GeneratedColumn<String> get artistSearch => $composableBuilder(
    column: $table.artistSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumSearch => $composableBuilder(
    column: $table.albumSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumArtistSearch => $composableBuilder(
    column: $table.albumArtistSearch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genreSearch => $composableBuilder(
    column: $table.genreSearch,
    builder: (column) => column,
  );
}

class $TrackSearchTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          TrackSearch,
          TrackSearchData,
          $TrackSearchFilterComposer,
          $TrackSearchOrderingComposer,
          $TrackSearchAnnotationComposer,
          $TrackSearchCreateCompanionBuilder,
          $TrackSearchUpdateCompanionBuilder,
          (
            TrackSearchData,
            BaseReferences<_$LibraryDatabase, TrackSearch, TrackSearchData>,
          ),
          TrackSearchData,
          PrefetchHooks Function()
        > {
  $TrackSearchTableManager(_$LibraryDatabase db, TrackSearch table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TrackSearchFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TrackSearchOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TrackSearchAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> titleSort = const Value.absent(),
                Value<String> artistSearch = const Value.absent(),
                Value<String> albumSearch = const Value.absent(),
                Value<String> albumArtistSearch = const Value.absent(),
                Value<String> genreSearch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackSearchCompanion(
                titleSort: titleSort,
                artistSearch: artistSearch,
                albumSearch: albumSearch,
                albumArtistSearch: albumArtistSearch,
                genreSearch: genreSearch,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleSort,
                required String artistSearch,
                required String albumSearch,
                required String albumArtistSearch,
                required String genreSearch,
                Value<int> rowid = const Value.absent(),
              }) => TrackSearchCompanion.insert(
                titleSort: titleSort,
                artistSearch: artistSearch,
                albumSearch: albumSearch,
                albumArtistSearch: albumArtistSearch,
                genreSearch: genreSearch,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<TrackSearch, TrackSearchData>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    TrackSearch,
                    TrackSearchData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $TrackSearchProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      TrackSearch,
      TrackSearchData,
      $TrackSearchFilterComposer,
      $TrackSearchOrderingComposer,
      $TrackSearchAnnotationComposer,
      $TrackSearchCreateCompanionBuilder,
      $TrackSearchUpdateCompanionBuilder,
      (
        TrackSearchData,
        BaseReferences<_$LibraryDatabase, TrackSearch, TrackSearchData>,
      ),
      TrackSearchData,
      PrefetchHooks Function()
    >;
typedef $$TrackArtistsTableCreateCompanionBuilder =
    TrackArtistsCompanion Function({
      required int trackId,
      required String artistKey,
      required String artistName,
      Value<int> rowid,
    });
typedef $$TrackArtistsTableUpdateCompanionBuilder =
    TrackArtistsCompanion Function({
      Value<int> trackId,
      Value<String> artistKey,
      Value<String> artistName,
      Value<int> rowid,
    });

final class $$TrackArtistsTableReferences
    extends BaseReferences<_$LibraryDatabase, $TrackArtistsTable, TrackArtist> {
  $$TrackArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$LibraryDatabase db) =>
      db.tracks.createAlias('track_artists__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackArtistsTableFilterComposer
    extends Composer<_$LibraryDatabase, $TrackArtistsTable> {
  $$TrackArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackArtistsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $TrackArtistsTable> {
  $$TrackArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackArtistsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $TrackArtistsTable> {
  $$TrackArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistKey =>
      $composableBuilder(column: $table.artistKey, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackArtistsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $TrackArtistsTable,
          TrackArtist,
          $$TrackArtistsTableFilterComposer,
          $$TrackArtistsTableOrderingComposer,
          $$TrackArtistsTableAnnotationComposer,
          $$TrackArtistsTableCreateCompanionBuilder,
          $$TrackArtistsTableUpdateCompanionBuilder,
          (TrackArtist, $$TrackArtistsTableReferences),
          TrackArtist,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackArtistsTableTableManager(
    _$LibraryDatabase db,
    $TrackArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> artistKey = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackArtistsCompanion(
                trackId: trackId,
                artistKey: artistKey,
                artistName: artistName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int trackId,
                required String artistKey,
                required String artistName,
                Value<int> rowid = const Value.absent(),
              }) => TrackArtistsCompanion.insert(
                trackId: trackId,
                artistKey: artistKey,
                artistName: artistName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackArtistsTable, TrackArtist>(table),
                  $$TrackArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackArtistsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackArtistsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $TrackArtistsTable,
      TrackArtist,
      $$TrackArtistsTableFilterComposer,
      $$TrackArtistsTableOrderingComposer,
      $$TrackArtistsTableAnnotationComposer,
      $$TrackArtistsTableCreateCompanionBuilder,
      $$TrackArtistsTableUpdateCompanionBuilder,
      (TrackArtist, $$TrackArtistsTableReferences),
      TrackArtist,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$CoverColorsTableCreateCompanionBuilder =
    CoverColorsCompanion Function({
      required String coverKey,
      required int seed,
      required String palette,
      required int algoVersion,
      Value<int> rowid,
    });
typedef $$CoverColorsTableUpdateCompanionBuilder =
    CoverColorsCompanion Function({
      Value<String> coverKey,
      Value<int> seed,
      Value<String> palette,
      Value<int> algoVersion,
      Value<int> rowid,
    });

class $$CoverColorsTableFilterComposer
    extends Composer<_$LibraryDatabase, $CoverColorsTable> {
  $$CoverColorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get palette => $composableBuilder(
    column: $table.palette,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoverColorsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $CoverColorsTable> {
  $$CoverColorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get palette => $composableBuilder(
    column: $table.palette,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoverColorsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $CoverColorsTable> {
  $$CoverColorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get coverKey =>
      $composableBuilder(column: $table.coverKey, builder: (column) => column);

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumn<String> get palette =>
      $composableBuilder(column: $table.palette, builder: (column) => column);

  GeneratedColumn<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => column,
  );
}

class $$CoverColorsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $CoverColorsTable,
          CoverColor,
          $$CoverColorsTableFilterComposer,
          $$CoverColorsTableOrderingComposer,
          $$CoverColorsTableAnnotationComposer,
          $$CoverColorsTableCreateCompanionBuilder,
          $$CoverColorsTableUpdateCompanionBuilder,
          (
            CoverColor,
            BaseReferences<_$LibraryDatabase, $CoverColorsTable, CoverColor>,
          ),
          CoverColor,
          PrefetchHooks Function()
        > {
  $$CoverColorsTableTableManager(_$LibraryDatabase db, $CoverColorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoverColorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoverColorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoverColorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> coverKey = const Value.absent(),
                Value<int> seed = const Value.absent(),
                Value<String> palette = const Value.absent(),
                Value<int> algoVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoverColorsCompanion(
                coverKey: coverKey,
                seed: seed,
                palette: palette,
                algoVersion: algoVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String coverKey,
                required int seed,
                required String palette,
                required int algoVersion,
                Value<int> rowid = const Value.absent(),
              }) => CoverColorsCompanion.insert(
                coverKey: coverKey,
                seed: seed,
                palette: palette,
                algoVersion: algoVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoverColorsTable, CoverColor>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $CoverColorsTable,
                    CoverColor
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoverColorsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $CoverColorsTable,
      CoverColor,
      $$CoverColorsTableFilterComposer,
      $$CoverColorsTableOrderingComposer,
      $$CoverColorsTableAnnotationComposer,
      $$CoverColorsTableCreateCompanionBuilder,
      $$CoverColorsTableUpdateCompanionBuilder,
      (
        CoverColor,
        BaseReferences<_$LibraryDatabase, $CoverColorsTable, CoverColor>,
      ),
      CoverColor,
      PrefetchHooks Function()
    >;
typedef $$ExcludedFoldersTableCreateCompanionBuilder =
    ExcludedFoldersCompanion Function({
      Value<int> id,
      required String path,
      required int addedAt,
    });
typedef $$ExcludedFoldersTableUpdateCompanionBuilder =
    ExcludedFoldersCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<int> addedAt,
    });

class $$ExcludedFoldersTableFilterComposer
    extends Composer<_$LibraryDatabase, $ExcludedFoldersTable> {
  $$ExcludedFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExcludedFoldersTableOrderingComposer
    extends Composer<_$LibraryDatabase, $ExcludedFoldersTable> {
  $$ExcludedFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExcludedFoldersTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $ExcludedFoldersTable> {
  $$ExcludedFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$ExcludedFoldersTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $ExcludedFoldersTable,
          ExcludedFolder,
          $$ExcludedFoldersTableFilterComposer,
          $$ExcludedFoldersTableOrderingComposer,
          $$ExcludedFoldersTableAnnotationComposer,
          $$ExcludedFoldersTableCreateCompanionBuilder,
          $$ExcludedFoldersTableUpdateCompanionBuilder,
          (
            ExcludedFolder,
            BaseReferences<
              _$LibraryDatabase,
              $ExcludedFoldersTable,
              ExcludedFolder
            >,
          ),
          ExcludedFolder,
          PrefetchHooks Function()
        > {
  $$ExcludedFoldersTableTableManager(
    _$LibraryDatabase db,
    $ExcludedFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExcludedFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExcludedFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExcludedFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> path = const Value.absent(),
            Value<int> addedAt = const Value.absent(),
          }) => ExcludedFoldersCompanion(id: id, path: path, addedAt: addedAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int addedAt,
              }) => ExcludedFoldersCompanion.insert(
                id: id,
                path: path,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExcludedFoldersTable, ExcludedFolder>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $ExcludedFoldersTable,
                    ExcludedFolder
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExcludedFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $ExcludedFoldersTable,
      ExcludedFolder,
      $$ExcludedFoldersTableFilterComposer,
      $$ExcludedFoldersTableOrderingComposer,
      $$ExcludedFoldersTableAnnotationComposer,
      $$ExcludedFoldersTableCreateCompanionBuilder,
      $$ExcludedFoldersTableUpdateCompanionBuilder,
      (
        ExcludedFolder,
        BaseReferences<
          _$LibraryDatabase,
          $ExcludedFoldersTable,
          ExcludedFolder
        >,
      ),
      ExcludedFolder,
      PrefetchHooks Function()
    >;
typedef $$LyricTranslationsTableCreateCompanionBuilder =
    LyricTranslationsCompanion Function({
      required String contentHash,
      required String provider,
      required String targetLang,
      Value<String?> sourceLang,
      required String linesJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$LyricTranslationsTableUpdateCompanionBuilder =
    LyricTranslationsCompanion Function({
      Value<String> contentHash,
      Value<String> provider,
      Value<String> targetLang,
      Value<String?> sourceLang,
      Value<String> linesJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$LyricTranslationsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationsTable> {
  $$LyricTranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linesJson => $composableBuilder(
    column: $table.linesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricTranslationsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationsTable> {
  $$LyricTranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linesJson => $composableBuilder(
    column: $table.linesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricTranslationsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationsTable> {
  $$LyricTranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linesJson =>
      $composableBuilder(column: $table.linesJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LyricTranslationsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LyricTranslationsTable,
          LyricTranslationRow,
          $$LyricTranslationsTableFilterComposer,
          $$LyricTranslationsTableOrderingComposer,
          $$LyricTranslationsTableAnnotationComposer,
          $$LyricTranslationsTableCreateCompanionBuilder,
          $$LyricTranslationsTableUpdateCompanionBuilder,
          (
            LyricTranslationRow,
            BaseReferences<
              _$LibraryDatabase,
              $LyricTranslationsTable,
              LyricTranslationRow
            >,
          ),
          LyricTranslationRow,
          PrefetchHooks Function()
        > {
  $$LyricTranslationsTableTableManager(
    _$LibraryDatabase db,
    $LyricTranslationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricTranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricTranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricTranslationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> contentHash = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> targetLang = const Value.absent(),
                Value<String?> sourceLang = const Value.absent(),
                Value<String> linesJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricTranslationsCompanion(
                contentHash: contentHash,
                provider: provider,
                targetLang: targetLang,
                sourceLang: sourceLang,
                linesJson: linesJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentHash,
                required String provider,
                required String targetLang,
                Value<String?> sourceLang = const Value.absent(),
                required String linesJson,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LyricTranslationsCompanion.insert(
                contentHash: contentHash,
                provider: provider,
                targetLang: targetLang,
                sourceLang: sourceLang,
                linesJson: linesJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricTranslationsTable, LyricTranslationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LibraryDatabase,
                    $LyricTranslationsTable,
                    LyricTranslationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricTranslationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LyricTranslationsTable,
      LyricTranslationRow,
      $$LyricTranslationsTableFilterComposer,
      $$LyricTranslationsTableOrderingComposer,
      $$LyricTranslationsTableAnnotationComposer,
      $$LyricTranslationsTableCreateCompanionBuilder,
      $$LyricTranslationsTableUpdateCompanionBuilder,
      (
        LyricTranslationRow,
        BaseReferences<
          _$LibraryDatabase,
          $LyricTranslationsTable,
          LyricTranslationRow
        >,
      ),
      LyricTranslationRow,
      PrefetchHooks Function()
    >;
typedef $$LyricTranslationPrefsTableCreateCompanionBuilder =
    LyricTranslationPrefsCompanion Function({
      required String contentHash,
      required String targetLang,
      Value<int> rowid,
    });
typedef $$LyricTranslationPrefsTableUpdateCompanionBuilder =
    LyricTranslationPrefsCompanion Function({
      Value<String> contentHash,
      Value<String> targetLang,
      Value<int> rowid,
    });

class $$LyricTranslationPrefsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationPrefsTable> {
  $$LyricTranslationPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricTranslationPrefsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationPrefsTable> {
  $$LyricTranslationPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricTranslationPrefsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LyricTranslationPrefsTable> {
  $$LyricTranslationPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => column,
  );
}

class $$LyricTranslationPrefsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LyricTranslationPrefsTable,
          LyricTranslationPrefRow,
          $$LyricTranslationPrefsTableFilterComposer,
          $$LyricTranslationPrefsTableOrderingComposer,
          $$LyricTranslationPrefsTableAnnotationComposer,
          $$LyricTranslationPrefsTableCreateCompanionBuilder,
          $$LyricTranslationPrefsTableUpdateCompanionBuilder,
          (
            LyricTranslationPrefRow,
            BaseReferences<
              _$LibraryDatabase,
              $LyricTranslationPrefsTable,
              LyricTranslationPrefRow
            >,
          ),
          LyricTranslationPrefRow,
          PrefetchHooks Function()
        > {
  $$LyricTranslationPrefsTableTableManager(
    _$LibraryDatabase db,
    $LyricTranslationPrefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricTranslationPrefsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LyricTranslationPrefsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LyricTranslationPrefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> contentHash = const Value.absent(),
                Value<String> targetLang = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricTranslationPrefsCompanion(
                contentHash: contentHash,
                targetLang: targetLang,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentHash,
                required String targetLang,
                Value<int> rowid = const Value.absent(),
              }) => LyricTranslationPrefsCompanion.insert(
                contentHash: contentHash,
                targetLang: targetLang,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LyricTranslationPrefsTable,
                    LyricTranslationPrefRow
                  >(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $LyricTranslationPrefsTable,
                    LyricTranslationPrefRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricTranslationPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LyricTranslationPrefsTable,
      LyricTranslationPrefRow,
      $$LyricTranslationPrefsTableFilterComposer,
      $$LyricTranslationPrefsTableOrderingComposer,
      $$LyricTranslationPrefsTableAnnotationComposer,
      $$LyricTranslationPrefsTableCreateCompanionBuilder,
      $$LyricTranslationPrefsTableUpdateCompanionBuilder,
      (
        LyricTranslationPrefRow,
        BaseReferences<
          _$LibraryDatabase,
          $LyricTranslationPrefsTable,
          LyricTranslationPrefRow
        >,
      ),
      LyricTranslationPrefRow,
      PrefetchHooks Function()
    >;
typedef $$OnlineLyricsTableCreateCompanionBuilder =
    OnlineLyricsCompanion Function({
      required String cacheKey,
      required String providerId,
      required String status,
      Value<String?> remoteId,
      Value<String?> syncedText,
      Value<String?> plainText,
      Value<bool> instrumental,
      Value<int?> remoteDurationMs,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$OnlineLyricsTableUpdateCompanionBuilder =
    OnlineLyricsCompanion Function({
      Value<String> cacheKey,
      Value<String> providerId,
      Value<String> status,
      Value<String?> remoteId,
      Value<String?> syncedText,
      Value<String?> plainText,
      Value<bool> instrumental,
      Value<int?> remoteDurationMs,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$OnlineLyricsTableFilterComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsTable> {
  $$OnlineLyricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnlineLyricsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsTable> {
  $$OnlineLyricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnlineLyricsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsTable> {
  $$OnlineLyricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$OnlineLyricsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $OnlineLyricsTable,
          OnlineLyricsRow,
          $$OnlineLyricsTableFilterComposer,
          $$OnlineLyricsTableOrderingComposer,
          $$OnlineLyricsTableAnnotationComposer,
          $$OnlineLyricsTableCreateCompanionBuilder,
          $$OnlineLyricsTableUpdateCompanionBuilder,
          (
            OnlineLyricsRow,
            BaseReferences<
              _$LibraryDatabase,
              $OnlineLyricsTable,
              OnlineLyricsRow
            >,
          ),
          OnlineLyricsRow,
          PrefetchHooks Function()
        > {
  $$OnlineLyricsTableTableManager(
    _$LibraryDatabase db,
    $OnlineLyricsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnlineLyricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnlineLyricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnlineLyricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> syncedText = const Value.absent(),
                Value<String?> plainText = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int?> remoteDurationMs = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineLyricsCompanion(
                cacheKey: cacheKey,
                providerId: providerId,
                status: status,
                remoteId: remoteId,
                syncedText: syncedText,
                plainText: plainText,
                instrumental: instrumental,
                remoteDurationMs: remoteDurationMs,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String providerId,
                required String status,
                Value<String?> remoteId = const Value.absent(),
                Value<String?> syncedText = const Value.absent(),
                Value<String?> plainText = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int?> remoteDurationMs = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => OnlineLyricsCompanion.insert(
                cacheKey: cacheKey,
                providerId: providerId,
                status: status,
                remoteId: remoteId,
                syncedText: syncedText,
                plainText: plainText,
                instrumental: instrumental,
                remoteDurationMs: remoteDurationMs,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OnlineLyricsTable, OnlineLyricsRow>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $OnlineLyricsTable,
                    OnlineLyricsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnlineLyricsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $OnlineLyricsTable,
      OnlineLyricsRow,
      $$OnlineLyricsTableFilterComposer,
      $$OnlineLyricsTableOrderingComposer,
      $$OnlineLyricsTableAnnotationComposer,
      $$OnlineLyricsTableCreateCompanionBuilder,
      $$OnlineLyricsTableUpdateCompanionBuilder,
      (
        OnlineLyricsRow,
        BaseReferences<_$LibraryDatabase, $OnlineLyricsTable, OnlineLyricsRow>,
      ),
      OnlineLyricsRow,
      PrefetchHooks Function()
    >;
typedef $$LyricsPinsTableCreateCompanionBuilder = LyricsPinsCompanion Function({
  required String trackKey,
  Value<String?> providerId,
  Value<String?> mode,
  Value<String?> remoteId,
  Value<String?> syncedText,
  Value<String?> plainText,
  Value<bool> instrumental,
  Value<int?> remoteDurationMs,
  required int pinnedAt,
  Value<int> rowid,
});
typedef $$LyricsPinsTableUpdateCompanionBuilder = LyricsPinsCompanion Function({
  Value<String> trackKey,
  Value<String?> providerId,
  Value<String?> mode,
  Value<String?> remoteId,
  Value<String?> syncedText,
  Value<String?> plainText,
  Value<bool> instrumental,
  Value<int?> remoteDurationMs,
  Value<int> pinnedAt,
  Value<int> rowid,
});

class $$LyricsPinsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LyricsPinsTable> {
  $$LyricsPinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricsPinsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LyricsPinsTable> {
  $$LyricsPinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricsPinsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LyricsPinsTable> {
  $$LyricsPinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get syncedText => $composableBuilder(
    column: $table.syncedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteDurationMs => $composableBuilder(
    column: $table.remoteDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$LyricsPinsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LyricsPinsTable,
          LyricsPinRow,
          $$LyricsPinsTableFilterComposer,
          $$LyricsPinsTableOrderingComposer,
          $$LyricsPinsTableAnnotationComposer,
          $$LyricsPinsTableCreateCompanionBuilder,
          $$LyricsPinsTableUpdateCompanionBuilder,
          (
            LyricsPinRow,
            BaseReferences<_$LibraryDatabase, $LyricsPinsTable, LyricsPinRow>,
          ),
          LyricsPinRow,
          PrefetchHooks Function()
        > {
  $$LyricsPinsTableTableManager(_$LibraryDatabase db, $LyricsPinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsPinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsPinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsPinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackKey = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> syncedText = const Value.absent(),
                Value<String?> plainText = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int?> remoteDurationMs = const Value.absent(),
                Value<int> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricsPinsCompanion(
                trackKey: trackKey,
                providerId: providerId,
                mode: mode,
                remoteId: remoteId,
                syncedText: syncedText,
                plainText: plainText,
                instrumental: instrumental,
                remoteDurationMs: remoteDurationMs,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackKey,
                Value<String?> providerId = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> syncedText = const Value.absent(),
                Value<String?> plainText = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int?> remoteDurationMs = const Value.absent(),
                required int pinnedAt,
                Value<int> rowid = const Value.absent(),
              }) => LyricsPinsCompanion.insert(
                trackKey: trackKey,
                providerId: providerId,
                mode: mode,
                remoteId: remoteId,
                syncedText: syncedText,
                plainText: plainText,
                instrumental: instrumental,
                remoteDurationMs: remoteDurationMs,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsPinsTable, LyricsPinRow>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $LyricsPinsTable,
                    LyricsPinRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricsPinsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LyricsPinsTable,
      LyricsPinRow,
      $$LyricsPinsTableFilterComposer,
      $$LyricsPinsTableOrderingComposer,
      $$LyricsPinsTableAnnotationComposer,
      $$LyricsPinsTableCreateCompanionBuilder,
      $$LyricsPinsTableUpdateCompanionBuilder,
      (
        LyricsPinRow,
        BaseReferences<_$LibraryDatabase, $LyricsPinsTable, LyricsPinRow>,
      ),
      LyricsPinRow,
      PrefetchHooks Function()
    >;
typedef $$OnlineLyricsRejectsTableCreateCompanionBuilder =
    OnlineLyricsRejectsCompanion Function({
      required String cacheKey,
      required String providerId,
      required String remoteId,
      Value<String?> contentHash,
      required int rejectedAt,
      Value<int> rowid,
    });
typedef $$OnlineLyricsRejectsTableUpdateCompanionBuilder =
    OnlineLyricsRejectsCompanion Function({
      Value<String> cacheKey,
      Value<String> providerId,
      Value<String> remoteId,
      Value<String?> contentHash,
      Value<int> rejectedAt,
      Value<int> rowid,
    });

class $$OnlineLyricsRejectsTableFilterComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsRejectsTable> {
  $$OnlineLyricsRejectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejectedAt => $composableBuilder(
    column: $table.rejectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnlineLyricsRejectsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsRejectsTable> {
  $$OnlineLyricsRejectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejectedAt => $composableBuilder(
    column: $table.rejectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnlineLyricsRejectsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $OnlineLyricsRejectsTable> {
  $$OnlineLyricsRejectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rejectedAt => $composableBuilder(
    column: $table.rejectedAt,
    builder: (column) => column,
  );
}

class $$OnlineLyricsRejectsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $OnlineLyricsRejectsTable,
          OnlineLyricsRejectRow,
          $$OnlineLyricsRejectsTableFilterComposer,
          $$OnlineLyricsRejectsTableOrderingComposer,
          $$OnlineLyricsRejectsTableAnnotationComposer,
          $$OnlineLyricsRejectsTableCreateCompanionBuilder,
          $$OnlineLyricsRejectsTableUpdateCompanionBuilder,
          (
            OnlineLyricsRejectRow,
            BaseReferences<
              _$LibraryDatabase,
              $OnlineLyricsRejectsTable,
              OnlineLyricsRejectRow
            >,
          ),
          OnlineLyricsRejectRow,
          PrefetchHooks Function()
        > {
  $$OnlineLyricsRejectsTableTableManager(
    _$LibraryDatabase db,
    $OnlineLyricsRejectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnlineLyricsRejectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnlineLyricsRejectsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OnlineLyricsRejectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int> rejectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineLyricsRejectsCompanion(
                cacheKey: cacheKey,
                providerId: providerId,
                remoteId: remoteId,
                contentHash: contentHash,
                rejectedAt: rejectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String providerId,
                required String remoteId,
                Value<String?> contentHash = const Value.absent(),
                required int rejectedAt,
                Value<int> rowid = const Value.absent(),
              }) => OnlineLyricsRejectsCompanion.insert(
                cacheKey: cacheKey,
                providerId: providerId,
                remoteId: remoteId,
                contentHash: contentHash,
                rejectedAt: rejectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OnlineLyricsRejectsTable, OnlineLyricsRejectRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LibraryDatabase,
                    $OnlineLyricsRejectsTable,
                    OnlineLyricsRejectRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnlineLyricsRejectsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $OnlineLyricsRejectsTable,
      OnlineLyricsRejectRow,
      $$OnlineLyricsRejectsTableFilterComposer,
      $$OnlineLyricsRejectsTableOrderingComposer,
      $$OnlineLyricsRejectsTableAnnotationComposer,
      $$OnlineLyricsRejectsTableCreateCompanionBuilder,
      $$OnlineLyricsRejectsTableUpdateCompanionBuilder,
      (
        OnlineLyricsRejectRow,
        BaseReferences<
          _$LibraryDatabase,
          $OnlineLyricsRejectsTable,
          OnlineLyricsRejectRow
        >,
      ),
      OnlineLyricsRejectRow,
      PrefetchHooks Function()
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$PlaysTableTableManager get plays =>
      $$PlaysTableTableManager(_db, _db.plays);
  $$PlayStatsTableTableManager get playStats =>
      $$PlayStatsTableTableManager(_db, _db.playStats);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
  $$LibraryRootsTableTableManager get libraryRoots =>
      $$LibraryRootsTableTableManager(_db, _db.libraryRoots);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $TrackSearchTableManager get trackSearch =>
      $TrackSearchTableManager(_db, _db.trackSearch);
  $$TrackArtistsTableTableManager get trackArtists =>
      $$TrackArtistsTableTableManager(_db, _db.trackArtists);
  $$CoverColorsTableTableManager get coverColors =>
      $$CoverColorsTableTableManager(_db, _db.coverColors);
  $$ExcludedFoldersTableTableManager get excludedFolders =>
      $$ExcludedFoldersTableTableManager(_db, _db.excludedFolders);
  $$LyricTranslationsTableTableManager get lyricTranslations =>
      $$LyricTranslationsTableTableManager(_db, _db.lyricTranslations);
  $$LyricTranslationPrefsTableTableManager get lyricTranslationPrefs =>
      $$LyricTranslationPrefsTableTableManager(_db, _db.lyricTranslationPrefs);
  $$OnlineLyricsTableTableManager get onlineLyrics =>
      $$OnlineLyricsTableTableManager(_db, _db.onlineLyrics);
  $$LyricsPinsTableTableManager get lyricsPins =>
      $$LyricsPinsTableTableManager(_db, _db.lyricsPins);
  $$OnlineLyricsRejectsTableTableManager get onlineLyricsRejects =>
      $$OnlineLyricsRejectsTableTableManager(_db, _db.onlineLyricsRejects);
}
