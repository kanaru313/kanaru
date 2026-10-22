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
  late final Index trackArtistsTrack = Index(
    'track_artists_track',
    'CREATE INDEX track_artists_track ON track_artists (track_id)',
  );
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
    trackArtistsTrack,
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
}
