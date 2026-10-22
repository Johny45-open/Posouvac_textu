// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, SongEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _tempoMeta = const VerificationMeta('tempo');
  @override
  late final GeneratedColumn<double> tempo = GeneratedColumn<double>(
    'tempo',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introDurationMeta = const VerificationMeta(
    'introDuration',
  );
  @override
  late final GeneratedColumn<double> introDuration = GeneratedColumn<double>(
    'intro_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPlayedMeta = const VerificationMeta(
    'isPlayed',
  );
  @override
  late final GeneratedColumn<bool> isPlayed = GeneratedColumn<bool>(
    'is_played',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_played" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _customFontSizeMeta = const VerificationMeta(
    'customFontSize',
  );
  @override
  late final GeneratedColumn<double> customFontSize = GeneratedColumn<double>(
    'custom_font_size',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customScrollSpeedMeta = const VerificationMeta(
    'customScrollSpeed',
  );
  @override
  late final GeneratedColumn<double> customScrollSpeed =
      GeneratedColumn<double>(
        'custom_scroll_speed',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    artist,
    title,
    tempo,
    introDuration,
    isFavorite,
    isPlayed,
    customFontSize,
    customScrollSpeed,
    duration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tempo')) {
      context.handle(
        _tempoMeta,
        tempo.isAcceptableOrUnknown(data['tempo']!, _tempoMeta),
      );
    }
    if (data.containsKey('intro_duration')) {
      context.handle(
        _introDurationMeta,
        introDuration.isAcceptableOrUnknown(
          data['intro_duration']!,
          _introDurationMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_played')) {
      context.handle(
        _isPlayedMeta,
        isPlayed.isAcceptableOrUnknown(data['is_played']!, _isPlayedMeta),
      );
    }
    if (data.containsKey('custom_font_size')) {
      context.handle(
        _customFontSizeMeta,
        customFontSize.isAcceptableOrUnknown(
          data['custom_font_size']!,
          _customFontSizeMeta,
        ),
      );
    }
    if (data.containsKey('custom_scroll_speed')) {
      context.handle(
        _customScrollSpeedMeta,
        customScrollSpeed.isAcceptableOrUnknown(
          data['custom_scroll_speed']!,
          _customScrollSpeedMeta,
        ),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      tempo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tempo'],
      ),
      introDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intro_duration'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_played'],
      )!,
      customFontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_font_size'],
      ),
      customScrollSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_scroll_speed'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class SongEntry extends DataClass implements Insertable<SongEntry> {
  final int id;
  final String filePath;
  final String artist;
  final String title;
  final double? tempo;
  final double? introDuration;
  final bool isFavorite;
  final bool isPlayed;
  final double? customFontSize;
  final double? customScrollSpeed;
  final int? duration;
  const SongEntry({
    required this.id,
    required this.filePath,
    required this.artist,
    required this.title,
    this.tempo,
    this.introDuration,
    required this.isFavorite,
    required this.isPlayed,
    this.customFontSize,
    this.customScrollSpeed,
    this.duration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['artist'] = Variable<String>(artist);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || tempo != null) {
      map['tempo'] = Variable<double>(tempo);
    }
    if (!nullToAbsent || introDuration != null) {
      map['intro_duration'] = Variable<double>(introDuration);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_played'] = Variable<bool>(isPlayed);
    if (!nullToAbsent || customFontSize != null) {
      map['custom_font_size'] = Variable<double>(customFontSize);
    }
    if (!nullToAbsent || customScrollSpeed != null) {
      map['custom_scroll_speed'] = Variable<double>(customScrollSpeed);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      filePath: Value(filePath),
      artist: Value(artist),
      title: Value(title),
      tempo: tempo == null && nullToAbsent
          ? const Value.absent()
          : Value(tempo),
      introDuration: introDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(introDuration),
      isFavorite: Value(isFavorite),
      isPlayed: Value(isPlayed),
      customFontSize: customFontSize == null && nullToAbsent
          ? const Value.absent()
          : Value(customFontSize),
      customScrollSpeed: customScrollSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(customScrollSpeed),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
    );
  }

  factory SongEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongEntry(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      artist: serializer.fromJson<String>(json['artist']),
      title: serializer.fromJson<String>(json['title']),
      tempo: serializer.fromJson<double?>(json['tempo']),
      introDuration: serializer.fromJson<double?>(json['introDuration']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isPlayed: serializer.fromJson<bool>(json['isPlayed']),
      customFontSize: serializer.fromJson<double?>(json['customFontSize']),
      customScrollSpeed: serializer.fromJson<double?>(
        json['customScrollSpeed'],
      ),
      duration: serializer.fromJson<int?>(json['duration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'artist': serializer.toJson<String>(artist),
      'title': serializer.toJson<String>(title),
      'tempo': serializer.toJson<double?>(tempo),
      'introDuration': serializer.toJson<double?>(introDuration),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isPlayed': serializer.toJson<bool>(isPlayed),
      'customFontSize': serializer.toJson<double?>(customFontSize),
      'customScrollSpeed': serializer.toJson<double?>(customScrollSpeed),
      'duration': serializer.toJson<int?>(duration),
    };
  }

  SongEntry copyWith({
    int? id,
    String? filePath,
    String? artist,
    String? title,
    Value<double?> tempo = const Value.absent(),
    Value<double?> introDuration = const Value.absent(),
    bool? isFavorite,
    bool? isPlayed,
    Value<double?> customFontSize = const Value.absent(),
    Value<double?> customScrollSpeed = const Value.absent(),
    Value<int?> duration = const Value.absent(),
  }) => SongEntry(
    id: id ?? this.id,
    filePath: filePath ?? this.filePath,
    artist: artist ?? this.artist,
    title: title ?? this.title,
    tempo: tempo.present ? tempo.value : this.tempo,
    introDuration: introDuration.present
        ? introDuration.value
        : this.introDuration,
    isFavorite: isFavorite ?? this.isFavorite,
    isPlayed: isPlayed ?? this.isPlayed,
    customFontSize: customFontSize.present
        ? customFontSize.value
        : this.customFontSize,
    customScrollSpeed: customScrollSpeed.present
        ? customScrollSpeed.value
        : this.customScrollSpeed,
    duration: duration.present ? duration.value : this.duration,
  );
  SongEntry copyWithCompanion(SongsCompanion data) {
    return SongEntry(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      artist: data.artist.present ? data.artist.value : this.artist,
      title: data.title.present ? data.title.value : this.title,
      tempo: data.tempo.present ? data.tempo.value : this.tempo,
      introDuration: data.introDuration.present
          ? data.introDuration.value
          : this.introDuration,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isPlayed: data.isPlayed.present ? data.isPlayed.value : this.isPlayed,
      customFontSize: data.customFontSize.present
          ? data.customFontSize.value
          : this.customFontSize,
      customScrollSpeed: data.customScrollSpeed.present
          ? data.customScrollSpeed.value
          : this.customScrollSpeed,
      duration: data.duration.present ? data.duration.value : this.duration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongEntry(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('artist: $artist, ')
          ..write('title: $title, ')
          ..write('tempo: $tempo, ')
          ..write('introDuration: $introDuration, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isPlayed: $isPlayed, ')
          ..write('customFontSize: $customFontSize, ')
          ..write('customScrollSpeed: $customScrollSpeed, ')
          ..write('duration: $duration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filePath,
    artist,
    title,
    tempo,
    introDuration,
    isFavorite,
    isPlayed,
    customFontSize,
    customScrollSpeed,
    duration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongEntry &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.artist == this.artist &&
          other.title == this.title &&
          other.tempo == this.tempo &&
          other.introDuration == this.introDuration &&
          other.isFavorite == this.isFavorite &&
          other.isPlayed == this.isPlayed &&
          other.customFontSize == this.customFontSize &&
          other.customScrollSpeed == this.customScrollSpeed &&
          other.duration == this.duration);
}

class SongsCompanion extends UpdateCompanion<SongEntry> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> artist;
  final Value<String> title;
  final Value<double?> tempo;
  final Value<double?> introDuration;
  final Value<bool> isFavorite;
  final Value<bool> isPlayed;
  final Value<double?> customFontSize;
  final Value<double?> customScrollSpeed;
  final Value<int?> duration;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.artist = const Value.absent(),
    this.title = const Value.absent(),
    this.tempo = const Value.absent(),
    this.introDuration = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isPlayed = const Value.absent(),
    this.customFontSize = const Value.absent(),
    this.customScrollSpeed = const Value.absent(),
    this.duration = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String artist,
    required String title,
    this.tempo = const Value.absent(),
    this.introDuration = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isPlayed = const Value.absent(),
    this.customFontSize = const Value.absent(),
    this.customScrollSpeed = const Value.absent(),
    this.duration = const Value.absent(),
  }) : filePath = Value(filePath),
       artist = Value(artist),
       title = Value(title);
  static Insertable<SongEntry> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? artist,
    Expression<String>? title,
    Expression<double>? tempo,
    Expression<double>? introDuration,
    Expression<bool>? isFavorite,
    Expression<bool>? isPlayed,
    Expression<double>? customFontSize,
    Expression<double>? customScrollSpeed,
    Expression<int>? duration,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (artist != null) 'artist': artist,
      if (title != null) 'title': title,
      if (tempo != null) 'tempo': tempo,
      if (introDuration != null) 'intro_duration': introDuration,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isPlayed != null) 'is_played': isPlayed,
      if (customFontSize != null) 'custom_font_size': customFontSize,
      if (customScrollSpeed != null) 'custom_scroll_speed': customScrollSpeed,
      if (duration != null) 'duration': duration,
    });
  }

  SongsCompanion copyWith({
    Value<int>? id,
    Value<String>? filePath,
    Value<String>? artist,
    Value<String>? title,
    Value<double?>? tempo,
    Value<double?>? introDuration,
    Value<bool>? isFavorite,
    Value<bool>? isPlayed,
    Value<double?>? customFontSize,
    Value<double?>? customScrollSpeed,
    Value<int?>? duration,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      artist: artist ?? this.artist,
      title: title ?? this.title,
      tempo: tempo ?? this.tempo,
      introDuration: introDuration ?? this.introDuration,
      isFavorite: isFavorite ?? this.isFavorite,
      isPlayed: isPlayed ?? this.isPlayed,
      customFontSize: customFontSize ?? this.customFontSize,
      customScrollSpeed: customScrollSpeed ?? this.customScrollSpeed,
      duration: duration ?? this.duration,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (tempo.present) {
      map['tempo'] = Variable<double>(tempo.value);
    }
    if (introDuration.present) {
      map['intro_duration'] = Variable<double>(introDuration.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isPlayed.present) {
      map['is_played'] = Variable<bool>(isPlayed.value);
    }
    if (customFontSize.present) {
      map['custom_font_size'] = Variable<double>(customFontSize.value);
    }
    if (customScrollSpeed.present) {
      map['custom_scroll_speed'] = Variable<double>(customScrollSpeed.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('artist: $artist, ')
          ..write('title: $title, ')
          ..write('tempo: $tempo, ')
          ..write('introDuration: $introDuration, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isPlayed: $isPlayed, ')
          ..write('customFontSize: $customFontSize, ')
          ..write('customScrollSpeed: $customScrollSpeed, ')
          ..write('duration: $duration')
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
  static const VerificationMeta _playlistUidMeta = const VerificationMeta(
    'playlistUid',
  );
  @override
  late final GeneratedColumn<String> playlistUid = GeneratedColumn<String>(
    'playlist_uid',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(playlistUid.length).isBiggerThan(const Constant(0)),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, playlistUid];
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
    if (data.containsKey('playlist_uid')) {
      context.handle(
        _playlistUidMeta,
        playlistUid.isAcceptableOrUnknown(
          data['playlist_uid']!,
          _playlistUidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playlistUidMeta);
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
      playlistUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_uid'],
      )!,
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

  /// Přenosová identita setlistu (UUID v4).
  /// Unikátnost i neprázdnost vynucuje SQL (UNIQUE + CHECK), ne jen kód –
  /// viz schéma v13 (etapa A1.2).
  final String playlistUid;
  const Playlist({
    required this.id,
    required this.name,
    required this.playlistUid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['playlist_uid'] = Variable<String>(playlistUid);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      playlistUid: Value(playlistUid),
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
      playlistUid: serializer.fromJson<String>(json['playlistUid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'playlistUid': serializer.toJson<String>(playlistUid),
    };
  }

  Playlist copyWith({int? id, String? name, String? playlistUid}) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    playlistUid: playlistUid ?? this.playlistUid,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      playlistUid: data.playlistUid.present
          ? data.playlistUid.value
          : this.playlistUid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('playlistUid: $playlistUid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, playlistUid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.playlistUid == this.playlistUid);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> playlistUid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.playlistUid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String playlistUid,
  }) : name = Value(name),
       playlistUid = Value(playlistUid);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? playlistUid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (playlistUid != null) 'playlist_uid': playlistUid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? playlistUid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      playlistUid: playlistUid ?? this.playlistUid,
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
    if (playlistUid.present) {
      map['playlist_uid'] = Variable<String>(playlistUid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('playlistUid: $playlistUid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistSongsTable extends PlaylistSongs
    with TableInfo<$PlaylistSongsTable, PlaylistSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistSongsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(occurrenceId.length).isBiggerThan(const Constant(0)),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tempoMeta = const VerificationMeta('tempo');
  @override
  late final GeneratedColumn<double> tempo = GeneratedColumn<double>(
    'tempo',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scrollSpeedMeta = const VerificationMeta(
    'scrollSpeed',
  );
  @override
  late final GeneratedColumn<double> scrollSpeed = GeneratedColumn<double>(
    'scroll_speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introDurationMeta = const VerificationMeta(
    'introDuration',
  );
  @override
  late final GeneratedColumn<double> introDuration = GeneratedColumn<double>(
    'intro_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stopMarksOverrideMeta = const VerificationMeta(
    'stopMarksOverride',
  );
  @override
  late final GeneratedColumn<bool> stopMarksOverride = GeneratedColumn<bool>(
    'stop_marks_override',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stop_marks_override" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    occurrenceId,
    playlistId,
    songId,
    orderIndex,
    tempo,
    scrollSpeed,
    introDuration,
    stopMarksOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistSong> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceIdMeta);
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('tempo')) {
      context.handle(
        _tempoMeta,
        tempo.isAcceptableOrUnknown(data['tempo']!, _tempoMeta),
      );
    }
    if (data.containsKey('scroll_speed')) {
      context.handle(
        _scrollSpeedMeta,
        scrollSpeed.isAcceptableOrUnknown(
          data['scroll_speed']!,
          _scrollSpeedMeta,
        ),
      );
    }
    if (data.containsKey('intro_duration')) {
      context.handle(
        _introDurationMeta,
        introDuration.isAcceptableOrUnknown(
          data['intro_duration']!,
          _introDurationMeta,
        ),
      );
    }
    if (data.containsKey('stop_marks_override')) {
      context.handle(
        _stopMarksOverrideMeta,
        stopMarksOverride.isAcceptableOrUnknown(
          data['stop_marks_override']!,
          _stopMarksOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistSong(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      tempo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tempo'],
      ),
      scrollSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scroll_speed'],
      ),
      introDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intro_duration'],
      ),
      stopMarksOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stop_marks_override'],
      ),
    );
  }

  @override
  $PlaylistSongsTable createAlias(String alias) {
    return $PlaylistSongsTable(attachedDatabase, alias);
  }
}

class PlaylistSong extends DataClass implements Insertable<PlaylistSong> {
  final int id;

  /// Stabilní přenosový identifikátor výskytu (UUID v4).
  /// Unikátnost i neprázdnost vynucuje SQL (UNIQUE + CHECK).
  final String occurrenceId;
  final int playlistId;
  final int songId;
  final int orderIndex;
  final double? tempo;

  /// Per-výskytové rychlosti posuvu (null = zděděné ze skladby/globální).
  final double? scrollSpeed;

  /// Per-výskytová délka úvodu v sekundách (null = zděděné ze skladby).
  final double? introDuration;

  /// Tri-stav výskytových zarážek:
  ///  * null  – zarážky zděděné ze skladby (výchozí stav, stav 1),
  ///  * false – pro daný výskyt výslovně žádné zarážky (stav 3),
  ///  * true  – použít vlastní seznam zarážek daného výskytu,
  ///            seznam může být prázdný nebo obsahovat více položek (stav 2).
  /// Samotná absence řádků v stop_marks první a třetí stav nerozlišuje.
  final bool? stopMarksOverride;
  const PlaylistSong({
    required this.id,
    required this.occurrenceId,
    required this.playlistId,
    required this.songId,
    required this.orderIndex,
    this.tempo,
    this.scrollSpeed,
    this.introDuration,
    this.stopMarksOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurrence_id'] = Variable<String>(occurrenceId);
    map['playlist_id'] = Variable<int>(playlistId);
    map['song_id'] = Variable<int>(songId);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || tempo != null) {
      map['tempo'] = Variable<double>(tempo);
    }
    if (!nullToAbsent || scrollSpeed != null) {
      map['scroll_speed'] = Variable<double>(scrollSpeed);
    }
    if (!nullToAbsent || introDuration != null) {
      map['intro_duration'] = Variable<double>(introDuration);
    }
    if (!nullToAbsent || stopMarksOverride != null) {
      map['stop_marks_override'] = Variable<bool>(stopMarksOverride);
    }
    return map;
  }

  PlaylistSongsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistSongsCompanion(
      id: Value(id),
      occurrenceId: Value(occurrenceId),
      playlistId: Value(playlistId),
      songId: Value(songId),
      orderIndex: Value(orderIndex),
      tempo: tempo == null && nullToAbsent
          ? const Value.absent()
          : Value(tempo),
      scrollSpeed: scrollSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(scrollSpeed),
      introDuration: introDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(introDuration),
      stopMarksOverride: stopMarksOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(stopMarksOverride),
    );
  }

  factory PlaylistSong.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistSong(
      id: serializer.fromJson<int>(json['id']),
      occurrenceId: serializer.fromJson<String>(json['occurrenceId']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      songId: serializer.fromJson<int>(json['songId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      tempo: serializer.fromJson<double?>(json['tempo']),
      scrollSpeed: serializer.fromJson<double?>(json['scrollSpeed']),
      introDuration: serializer.fromJson<double?>(json['introDuration']),
      stopMarksOverride: serializer.fromJson<bool?>(json['stopMarksOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurrenceId': serializer.toJson<String>(occurrenceId),
      'playlistId': serializer.toJson<int>(playlistId),
      'songId': serializer.toJson<int>(songId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'tempo': serializer.toJson<double?>(tempo),
      'scrollSpeed': serializer.toJson<double?>(scrollSpeed),
      'introDuration': serializer.toJson<double?>(introDuration),
      'stopMarksOverride': serializer.toJson<bool?>(stopMarksOverride),
    };
  }

  PlaylistSong copyWith({
    int? id,
    String? occurrenceId,
    int? playlistId,
    int? songId,
    int? orderIndex,
    Value<double?> tempo = const Value.absent(),
    Value<double?> scrollSpeed = const Value.absent(),
    Value<double?> introDuration = const Value.absent(),
    Value<bool?> stopMarksOverride = const Value.absent(),
  }) => PlaylistSong(
    id: id ?? this.id,
    occurrenceId: occurrenceId ?? this.occurrenceId,
    playlistId: playlistId ?? this.playlistId,
    songId: songId ?? this.songId,
    orderIndex: orderIndex ?? this.orderIndex,
    tempo: tempo.present ? tempo.value : this.tempo,
    scrollSpeed: scrollSpeed.present ? scrollSpeed.value : this.scrollSpeed,
    introDuration: introDuration.present
        ? introDuration.value
        : this.introDuration,
    stopMarksOverride: stopMarksOverride.present
        ? stopMarksOverride.value
        : this.stopMarksOverride,
  );
  PlaylistSong copyWithCompanion(PlaylistSongsCompanion data) {
    return PlaylistSong(
      id: data.id.present ? data.id.value : this.id,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      tempo: data.tempo.present ? data.tempo.value : this.tempo,
      scrollSpeed: data.scrollSpeed.present
          ? data.scrollSpeed.value
          : this.scrollSpeed,
      introDuration: data.introDuration.present
          ? data.introDuration.value
          : this.introDuration,
      stopMarksOverride: data.stopMarksOverride.present
          ? data.stopMarksOverride.value
          : this.stopMarksOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSong(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('tempo: $tempo, ')
          ..write('scrollSpeed: $scrollSpeed, ')
          ..write('introDuration: $introDuration, ')
          ..write('stopMarksOverride: $stopMarksOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    occurrenceId,
    playlistId,
    songId,
    orderIndex,
    tempo,
    scrollSpeed,
    introDuration,
    stopMarksOverride,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistSong &&
          other.id == this.id &&
          other.occurrenceId == this.occurrenceId &&
          other.playlistId == this.playlistId &&
          other.songId == this.songId &&
          other.orderIndex == this.orderIndex &&
          other.tempo == this.tempo &&
          other.scrollSpeed == this.scrollSpeed &&
          other.introDuration == this.introDuration &&
          other.stopMarksOverride == this.stopMarksOverride);
}

class PlaylistSongsCompanion extends UpdateCompanion<PlaylistSong> {
  final Value<int> id;
  final Value<String> occurrenceId;
  final Value<int> playlistId;
  final Value<int> songId;
  final Value<int> orderIndex;
  final Value<double?> tempo;
  final Value<double?> scrollSpeed;
  final Value<double?> introDuration;
  final Value<bool?> stopMarksOverride;
  const PlaylistSongsCompanion({
    this.id = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.tempo = const Value.absent(),
    this.scrollSpeed = const Value.absent(),
    this.introDuration = const Value.absent(),
    this.stopMarksOverride = const Value.absent(),
  });
  PlaylistSongsCompanion.insert({
    this.id = const Value.absent(),
    required String occurrenceId,
    required int playlistId,
    required int songId,
    this.orderIndex = const Value.absent(),
    this.tempo = const Value.absent(),
    this.scrollSpeed = const Value.absent(),
    this.introDuration = const Value.absent(),
    this.stopMarksOverride = const Value.absent(),
  }) : occurrenceId = Value(occurrenceId),
       playlistId = Value(playlistId),
       songId = Value(songId);
  static Insertable<PlaylistSong> custom({
    Expression<int>? id,
    Expression<String>? occurrenceId,
    Expression<int>? playlistId,
    Expression<int>? songId,
    Expression<int>? orderIndex,
    Expression<double>? tempo,
    Expression<double>? scrollSpeed,
    Expression<double>? introDuration,
    Expression<bool>? stopMarksOverride,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (playlistId != null) 'playlist_id': playlistId,
      if (songId != null) 'song_id': songId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (tempo != null) 'tempo': tempo,
      if (scrollSpeed != null) 'scroll_speed': scrollSpeed,
      if (introDuration != null) 'intro_duration': introDuration,
      if (stopMarksOverride != null) 'stop_marks_override': stopMarksOverride,
    });
  }

  PlaylistSongsCompanion copyWith({
    Value<int>? id,
    Value<String>? occurrenceId,
    Value<int>? playlistId,
    Value<int>? songId,
    Value<int>? orderIndex,
    Value<double?>? tempo,
    Value<double?>? scrollSpeed,
    Value<double?>? introDuration,
    Value<bool?>? stopMarksOverride,
  }) {
    return PlaylistSongsCompanion(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      playlistId: playlistId ?? this.playlistId,
      songId: songId ?? this.songId,
      orderIndex: orderIndex ?? this.orderIndex,
      tempo: tempo ?? this.tempo,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      introDuration: introDuration ?? this.introDuration,
      stopMarksOverride: stopMarksOverride ?? this.stopMarksOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (tempo.present) {
      map['tempo'] = Variable<double>(tempo.value);
    }
    if (scrollSpeed.present) {
      map['scroll_speed'] = Variable<double>(scrollSpeed.value);
    }
    if (introDuration.present) {
      map['intro_duration'] = Variable<double>(introDuration.value);
    }
    if (stopMarksOverride.present) {
      map['stop_marks_override'] = Variable<bool>(stopMarksOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSongsCompanion(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('tempo: $tempo, ')
          ..write('scrollSpeed: $scrollSpeed, ')
          ..write('introDuration: $introDuration, ')
          ..write('stopMarksOverride: $stopMarksOverride')
          ..write(')'))
        .toString();
  }
}

class $StopMarksTable extends StopMarks
    with TableInfo<$StopMarksTable, StopMark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StopMarksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionRatioMeta = const VerificationMeta(
    'positionRatio',
  );
  @override
  late final GeneratedColumn<double> positionRatio = GeneratedColumn<double>(
    'position_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationBarsMeta = const VerificationMeta(
    'durationBars',
  );
  @override
  late final GeneratedColumn<int> durationBars = GeneratedColumn<int>(
    'duration_bars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIndexMeta = const VerificationMeta(
    'lineIndex',
  );
  @override
  late final GeneratedColumn<int> lineIndex = GeneratedColumn<int>(
    'line_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineTextMeta = const VerificationMeta(
    'lineText',
  );
  @override
  late final GeneratedColumn<String> lineText = GeneratedColumn<String>(
    'line_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playlistSongIdMeta = const VerificationMeta(
    'playlistSongId',
  );
  @override
  late final GeneratedColumn<int> playlistSongId = GeneratedColumn<int>(
    'playlist_song_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlist_songs (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    positionRatio,
    durationBars,
    lineIndex,
    lineText,
    playlistSongId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stop_marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<StopMark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position_ratio')) {
      context.handle(
        _positionRatioMeta,
        positionRatio.isAcceptableOrUnknown(
          data['position_ratio']!,
          _positionRatioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionRatioMeta);
    }
    if (data.containsKey('duration_bars')) {
      context.handle(
        _durationBarsMeta,
        durationBars.isAcceptableOrUnknown(
          data['duration_bars']!,
          _durationBarsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationBarsMeta);
    }
    if (data.containsKey('line_index')) {
      context.handle(
        _lineIndexMeta,
        lineIndex.isAcceptableOrUnknown(data['line_index']!, _lineIndexMeta),
      );
    }
    if (data.containsKey('line_text')) {
      context.handle(
        _lineTextMeta,
        lineText.isAcceptableOrUnknown(data['line_text']!, _lineTextMeta),
      );
    }
    if (data.containsKey('playlist_song_id')) {
      context.handle(
        _playlistSongIdMeta,
        playlistSongId.isAcceptableOrUnknown(
          data['playlist_song_id']!,
          _playlistSongIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StopMark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StopMark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_id'],
      )!,
      positionRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_ratio'],
      )!,
      durationBars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_bars'],
      )!,
      lineIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_index'],
      ),
      lineText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_text'],
      ),
      playlistSongId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_song_id'],
      ),
    );
  }

  @override
  $StopMarksTable createAlias(String alias) {
    return $StopMarksTable(attachedDatabase, alias);
  }
}

class StopMark extends DataClass implements Insertable<StopMark> {
  final int id;
  final int songId;
  final double positionRatio;
  final int durationBars;
  final int? lineIndex;
  final String? lineText;

  /// Konkrétní výskyt písně v setlistu (etapa A1.2).
  ///  * null  – zarážka patří skladbě a je sdílená všemi výskyty (stav po migraci),
  ///  * != null – zarážka patří konkrétnímu výskytu.
  /// Musí zůstat posledním sloupcem – migrace v13 jej přidává přes ALTER TABLE
  /// ADD COLUMN (na konci) a testy porovnávají schéma s čerstvou definicí Driftu.
  final int? playlistSongId;
  const StopMark({
    required this.id,
    required this.songId,
    required this.positionRatio,
    required this.durationBars,
    this.lineIndex,
    this.lineText,
    this.playlistSongId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['position_ratio'] = Variable<double>(positionRatio);
    map['duration_bars'] = Variable<int>(durationBars);
    if (!nullToAbsent || lineIndex != null) {
      map['line_index'] = Variable<int>(lineIndex);
    }
    if (!nullToAbsent || lineText != null) {
      map['line_text'] = Variable<String>(lineText);
    }
    if (!nullToAbsent || playlistSongId != null) {
      map['playlist_song_id'] = Variable<int>(playlistSongId);
    }
    return map;
  }

  StopMarksCompanion toCompanion(bool nullToAbsent) {
    return StopMarksCompanion(
      id: Value(id),
      songId: Value(songId),
      positionRatio: Value(positionRatio),
      durationBars: Value(durationBars),
      lineIndex: lineIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(lineIndex),
      lineText: lineText == null && nullToAbsent
          ? const Value.absent()
          : Value(lineText),
      playlistSongId: playlistSongId == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistSongId),
    );
  }

  factory StopMark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StopMark(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['songId']),
      positionRatio: serializer.fromJson<double>(json['positionRatio']),
      durationBars: serializer.fromJson<int>(json['durationBars']),
      lineIndex: serializer.fromJson<int?>(json['lineIndex']),
      lineText: serializer.fromJson<String?>(json['lineText']),
      playlistSongId: serializer.fromJson<int?>(json['playlistSongId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<int>(songId),
      'positionRatio': serializer.toJson<double>(positionRatio),
      'durationBars': serializer.toJson<int>(durationBars),
      'lineIndex': serializer.toJson<int?>(lineIndex),
      'lineText': serializer.toJson<String?>(lineText),
      'playlistSongId': serializer.toJson<int?>(playlistSongId),
    };
  }

  StopMark copyWith({
    int? id,
    int? songId,
    double? positionRatio,
    int? durationBars,
    Value<int?> lineIndex = const Value.absent(),
    Value<String?> lineText = const Value.absent(),
    Value<int?> playlistSongId = const Value.absent(),
  }) => StopMark(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    positionRatio: positionRatio ?? this.positionRatio,
    durationBars: durationBars ?? this.durationBars,
    lineIndex: lineIndex.present ? lineIndex.value : this.lineIndex,
    lineText: lineText.present ? lineText.value : this.lineText,
    playlistSongId: playlistSongId.present
        ? playlistSongId.value
        : this.playlistSongId,
  );
  StopMark copyWithCompanion(StopMarksCompanion data) {
    return StopMark(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      positionRatio: data.positionRatio.present
          ? data.positionRatio.value
          : this.positionRatio,
      durationBars: data.durationBars.present
          ? data.durationBars.value
          : this.durationBars,
      lineIndex: data.lineIndex.present ? data.lineIndex.value : this.lineIndex,
      lineText: data.lineText.present ? data.lineText.value : this.lineText,
      playlistSongId: data.playlistSongId.present
          ? data.playlistSongId.value
          : this.playlistSongId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StopMark(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('positionRatio: $positionRatio, ')
          ..write('durationBars: $durationBars, ')
          ..write('lineIndex: $lineIndex, ')
          ..write('lineText: $lineText, ')
          ..write('playlistSongId: $playlistSongId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songId,
    positionRatio,
    durationBars,
    lineIndex,
    lineText,
    playlistSongId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StopMark &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.positionRatio == this.positionRatio &&
          other.durationBars == this.durationBars &&
          other.lineIndex == this.lineIndex &&
          other.lineText == this.lineText &&
          other.playlistSongId == this.playlistSongId);
}

class StopMarksCompanion extends UpdateCompanion<StopMark> {
  final Value<int> id;
  final Value<int> songId;
  final Value<double> positionRatio;
  final Value<int> durationBars;
  final Value<int?> lineIndex;
  final Value<String?> lineText;
  final Value<int?> playlistSongId;
  const StopMarksCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.positionRatio = const Value.absent(),
    this.durationBars = const Value.absent(),
    this.lineIndex = const Value.absent(),
    this.lineText = const Value.absent(),
    this.playlistSongId = const Value.absent(),
  });
  StopMarksCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required double positionRatio,
    required int durationBars,
    this.lineIndex = const Value.absent(),
    this.lineText = const Value.absent(),
    this.playlistSongId = const Value.absent(),
  }) : songId = Value(songId),
       positionRatio = Value(positionRatio),
       durationBars = Value(durationBars);
  static Insertable<StopMark> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<double>? positionRatio,
    Expression<int>? durationBars,
    Expression<int>? lineIndex,
    Expression<String>? lineText,
    Expression<int>? playlistSongId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (positionRatio != null) 'position_ratio': positionRatio,
      if (durationBars != null) 'duration_bars': durationBars,
      if (lineIndex != null) 'line_index': lineIndex,
      if (lineText != null) 'line_text': lineText,
      if (playlistSongId != null) 'playlist_song_id': playlistSongId,
    });
  }

  StopMarksCompanion copyWith({
    Value<int>? id,
    Value<int>? songId,
    Value<double>? positionRatio,
    Value<int>? durationBars,
    Value<int?>? lineIndex,
    Value<String?>? lineText,
    Value<int?>? playlistSongId,
  }) {
    return StopMarksCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      positionRatio: positionRatio ?? this.positionRatio,
      durationBars: durationBars ?? this.durationBars,
      lineIndex: lineIndex ?? this.lineIndex,
      lineText: lineText ?? this.lineText,
      playlistSongId: playlistSongId ?? this.playlistSongId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (positionRatio.present) {
      map['position_ratio'] = Variable<double>(positionRatio.value);
    }
    if (durationBars.present) {
      map['duration_bars'] = Variable<int>(durationBars.value);
    }
    if (lineIndex.present) {
      map['line_index'] = Variable<int>(lineIndex.value);
    }
    if (lineText.present) {
      map['line_text'] = Variable<String>(lineText.value);
    }
    if (playlistSongId.present) {
      map['playlist_song_id'] = Variable<int>(playlistSongId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StopMarksCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('positionRatio: $positionRatio, ')
          ..write('durationBars: $durationBars, ')
          ..write('lineIndex: $lineIndex, ')
          ..write('lineText: $lineText, ')
          ..write('playlistSongId: $playlistSongId')
          ..write(')'))
        .toString();
  }
}

class $CustomStringsTable extends CustomStrings
    with TableInfo<$CustomStringsTable, CustomString> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomStringsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_strings';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomString> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CustomString map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomString(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $CustomStringsTable createAlias(String alias) {
    return $CustomStringsTable(attachedDatabase, alias);
  }
}

class CustomString extends DataClass implements Insertable<CustomString> {
  final String key;
  final String value;
  const CustomString({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  CustomStringsCompanion toCompanion(bool nullToAbsent) {
    return CustomStringsCompanion(key: Value(key), value: Value(value));
  }

  factory CustomString.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomString(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  CustomString copyWith({String? key, String? value}) =>
      CustomString(key: key ?? this.key, value: value ?? this.value);
  CustomString copyWithCompanion(CustomStringsCompanion data) {
    return CustomString(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomString(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomString &&
          other.key == this.key &&
          other.value == this.value);
}

class CustomStringsCompanion extends UpdateCompanion<CustomString> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const CustomStringsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomStringsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<CustomString> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomStringsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return CustomStringsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomStringsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiacriticMappingsTable extends DiacriticMappings
    with TableInfo<$DiacriticMappingsTable, DiacriticMappingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiacriticMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _normKeyMeta = const VerificationMeta(
    'normKey',
  );
  @override
  late final GeneratedColumn<String> normKey = GeneratedColumn<String>(
    'norm_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctedMeta = const VerificationMeta(
    'corrected',
  );
  @override
  late final GeneratedColumn<String> corrected = GeneratedColumn<String>(
    'corrected',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [normKey, corrected];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diacritic_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiacriticMappingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('norm_key')) {
      context.handle(
        _normKeyMeta,
        normKey.isAcceptableOrUnknown(data['norm_key']!, _normKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_normKeyMeta);
    }
    if (data.containsKey('corrected')) {
      context.handle(
        _correctedMeta,
        corrected.isAcceptableOrUnknown(data['corrected']!, _correctedMeta),
      );
    } else if (isInserting) {
      context.missing(_correctedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {normKey};
  @override
  DiacriticMappingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiacriticMappingEntry(
      normKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}norm_key'],
      )!,
      corrected: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}corrected'],
      )!,
    );
  }

  @override
  $DiacriticMappingsTable createAlias(String alias) {
    return $DiacriticMappingsTable(attachedDatabase, alias);
  }
}

class DiacriticMappingEntry extends DataClass
    implements Insertable<DiacriticMappingEntry> {
  final String normKey;
  final String corrected;
  const DiacriticMappingEntry({required this.normKey, required this.corrected});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['norm_key'] = Variable<String>(normKey);
    map['corrected'] = Variable<String>(corrected);
    return map;
  }

  DiacriticMappingsCompanion toCompanion(bool nullToAbsent) {
    return DiacriticMappingsCompanion(
      normKey: Value(normKey),
      corrected: Value(corrected),
    );
  }

  factory DiacriticMappingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiacriticMappingEntry(
      normKey: serializer.fromJson<String>(json['normKey']),
      corrected: serializer.fromJson<String>(json['corrected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'normKey': serializer.toJson<String>(normKey),
      'corrected': serializer.toJson<String>(corrected),
    };
  }

  DiacriticMappingEntry copyWith({String? normKey, String? corrected}) =>
      DiacriticMappingEntry(
        normKey: normKey ?? this.normKey,
        corrected: corrected ?? this.corrected,
      );
  DiacriticMappingEntry copyWithCompanion(DiacriticMappingsCompanion data) {
    return DiacriticMappingEntry(
      normKey: data.normKey.present ? data.normKey.value : this.normKey,
      corrected: data.corrected.present ? data.corrected.value : this.corrected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiacriticMappingEntry(')
          ..write('normKey: $normKey, ')
          ..write('corrected: $corrected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(normKey, corrected);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiacriticMappingEntry &&
          other.normKey == this.normKey &&
          other.corrected == this.corrected);
}

class DiacriticMappingsCompanion
    extends UpdateCompanion<DiacriticMappingEntry> {
  final Value<String> normKey;
  final Value<String> corrected;
  final Value<int> rowid;
  const DiacriticMappingsCompanion({
    this.normKey = const Value.absent(),
    this.corrected = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiacriticMappingsCompanion.insert({
    required String normKey,
    required String corrected,
    this.rowid = const Value.absent(),
  }) : normKey = Value(normKey),
       corrected = Value(corrected);
  static Insertable<DiacriticMappingEntry> custom({
    Expression<String>? normKey,
    Expression<String>? corrected,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (normKey != null) 'norm_key': normKey,
      if (corrected != null) 'corrected': corrected,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiacriticMappingsCompanion copyWith({
    Value<String>? normKey,
    Value<String>? corrected,
    Value<int>? rowid,
  }) {
    return DiacriticMappingsCompanion(
      normKey: normKey ?? this.normKey,
      corrected: corrected ?? this.corrected,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (normKey.present) {
      map['norm_key'] = Variable<String>(normKey.value);
    }
    if (corrected.present) {
      map['corrected'] = Variable<String>(corrected.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiacriticMappingsCompanion(')
          ..write('normKey: $normKey, ')
          ..write('corrected: $corrected, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistSongsTable playlistSongs = $PlaylistSongsTable(this);
  late final $StopMarksTable stopMarks = $StopMarksTable(this);
  late final $CustomStringsTable customStrings = $CustomStringsTable(this);
  late final $DiacriticMappingsTable diacriticMappings =
      $DiacriticMappingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    songs,
    playlists,
    playlistSongs,
    stopMarks,
    customStrings,
    diacriticMappings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_songs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_songs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stop_marks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlist_songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stop_marks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      Value<int> id,
      required String filePath,
      required String artist,
      required String title,
      Value<double?> tempo,
      Value<double?> introDuration,
      Value<bool> isFavorite,
      Value<bool> isPlayed,
      Value<double?> customFontSize,
      Value<double?> customScrollSpeed,
      Value<int?> duration,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<int> id,
      Value<String> filePath,
      Value<String> artist,
      Value<String> title,
      Value<double?> tempo,
      Value<double?> introDuration,
      Value<bool> isFavorite,
      Value<bool> isPlayed,
      Value<double?> customFontSize,
      Value<double?> customScrollSpeed,
      Value<int?> duration,
    });

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, SongEntry> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistSongsTable, List<PlaylistSong>>
  _playlistSongsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistSongs,
    aliasName: 'songs__id__playlist_songs__song_id',
  );

  $$PlaylistSongsTableProcessedTableManager get playlistSongsRefs {
    final manager = $$PlaylistSongsTableTableManager(
      $_db,
      $_db.playlistSongs,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistSongsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StopMarksTable, List<StopMark>>
  _stopMarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stopMarks,
    aliasName: 'songs__id__stop_marks__song_id',
  );

  $$StopMarksTableProcessedTableManager get stopMarksRefs {
    final manager = $$StopMarksTableTableManager(
      $_db,
      $_db.stopMarks,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stopMarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlayed => $composableBuilder(
    column: $table.isPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customFontSize => $composableBuilder(
    column: $table.customFontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customScrollSpeed => $composableBuilder(
    column: $table.customScrollSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistSongsRefs(
    Expression<bool> Function($$PlaylistSongsTableFilterComposer f) f,
  ) {
    final $$PlaylistSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableFilterComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stopMarksRefs(
    Expression<bool> Function($$StopMarksTableFilterComposer f) f,
  ) {
    final $$StopMarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopMarks,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopMarksTableFilterComposer(
            $db: $db,
            $table: $db.stopMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlayed => $composableBuilder(
    column: $table.isPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get customFontSize => $composableBuilder(
    column: $table.customFontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get customScrollSpeed => $composableBuilder(
    column: $table.customScrollSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get tempo =>
      $composableBuilder(column: $table.tempo, builder: (column) => column);

  GeneratedColumn<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPlayed =>
      $composableBuilder(column: $table.isPlayed, builder: (column) => column);

  GeneratedColumn<double> get customFontSize => $composableBuilder(
    column: $table.customFontSize,
    builder: (column) => column,
  );

  GeneratedColumn<double> get customScrollSpeed => $composableBuilder(
    column: $table.customScrollSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  Expression<T> playlistSongsRefs<T extends Object>(
    Expression<T> Function($$PlaylistSongsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stopMarksRefs<T extends Object>(
    Expression<T> Function($$StopMarksTableAnnotationComposer a) f,
  ) {
    final $$StopMarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopMarks,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopMarksTableAnnotationComposer(
            $db: $db,
            $table: $db.stopMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongsTable,
          SongEntry,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (SongEntry, $$SongsTableReferences),
          SongEntry,
          PrefetchHooks Function({bool playlistSongsRefs, bool stopMarksRefs})
        > {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<double?> tempo = const Value.absent(),
                Value<double?> introDuration = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isPlayed = const Value.absent(),
                Value<double?> customFontSize = const Value.absent(),
                Value<double?> customScrollSpeed = const Value.absent(),
                Value<int?> duration = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                filePath: filePath,
                artist: artist,
                title: title,
                tempo: tempo,
                introDuration: introDuration,
                isFavorite: isFavorite,
                isPlayed: isPlayed,
                customFontSize: customFontSize,
                customScrollSpeed: customScrollSpeed,
                duration: duration,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String filePath,
                required String artist,
                required String title,
                Value<double?> tempo = const Value.absent(),
                Value<double?> introDuration = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isPlayed = const Value.absent(),
                Value<double?> customFontSize = const Value.absent(),
                Value<double?> customScrollSpeed = const Value.absent(),
                Value<int?> duration = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                filePath: filePath,
                artist: artist,
                title: title,
                tempo: tempo,
                introDuration: introDuration,
                isFavorite: isFavorite,
                isPlayed: isPlayed,
                customFontSize: customFontSize,
                customScrollSpeed: customScrollSpeed,
                duration: duration,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SongsTable, SongEntry>(table),
                  $$SongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistSongsRefs = false, stopMarksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistSongsRefs) db.playlistSongs,
                    if (stopMarksRefs) db.stopMarks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistSongsRefs)
                        await $_getPrefetchedData<
                          SongEntry,
                          $SongsTable,
                          PlaylistSong
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._playlistSongsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistSongsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stopMarksRefs)
                        await $_getPrefetchedData<
                          SongEntry,
                          $SongsTable,
                          StopMark
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._stopMarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).stopMarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongsTable,
      SongEntry,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (SongEntry, $$SongsTableReferences),
      SongEntry,
      PrefetchHooks Function({bool playlistSongsRefs, bool stopMarksRefs})
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      required String name,
      required String playlistUid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> playlistUid,
    });

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistSongsTable, List<PlaylistSong>>
  _playlistSongsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistSongs,
    aliasName: 'playlists__id__playlist_songs__playlist_id',
  );

  $$PlaylistSongsTableProcessedTableManager get playlistSongsRefs {
    final manager = $$PlaylistSongsTableTableManager(
      $_db,
      $_db.playlistSongs,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistSongsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
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

  ColumnFilters<String> get playlistUid => $composableBuilder(
    column: $table.playlistUid,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistSongsRefs(
    Expression<bool> Function($$PlaylistSongsTableFilterComposer f) f,
  ) {
    final $$PlaylistSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableFilterComposer(
            $db: $db,
            $table: $db.playlistSongs,
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
    extends Composer<_$AppDatabase, $PlaylistsTable> {
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

  ColumnOrderings<String> get playlistUid => $composableBuilder(
    column: $table.playlistUid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
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

  GeneratedColumn<String> get playlistUid => $composableBuilder(
    column: $table.playlistUid,
    builder: (column) => column,
  );

  Expression<T> playlistSongsRefs<T extends Object>(
    Expression<T> Function($$PlaylistSongsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistSongs,
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
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistSongsRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
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
                Value<String> playlistUid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                playlistUid: playlistUid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String playlistUid,
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                playlistUid: playlistUid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistSongsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistSongsRefs) db.playlistSongs,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistSongsRefs)
                    await $_getPrefetchedData<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistSong
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistSongsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistSongsRefs,
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
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistSongsRefs})
    >;
typedef $$PlaylistSongsTableCreateCompanionBuilder =
    PlaylistSongsCompanion Function({
      Value<int> id,
      required String occurrenceId,
      required int playlistId,
      required int songId,
      Value<int> orderIndex,
      Value<double?> tempo,
      Value<double?> scrollSpeed,
      Value<double?> introDuration,
      Value<bool?> stopMarksOverride,
    });
typedef $$PlaylistSongsTableUpdateCompanionBuilder =
    PlaylistSongsCompanion Function({
      Value<int> id,
      Value<String> occurrenceId,
      Value<int> playlistId,
      Value<int> songId,
      Value<int> orderIndex,
      Value<double?> tempo,
      Value<double?> scrollSpeed,
      Value<double?> introDuration,
      Value<bool?> stopMarksOverride,
    });

final class $$PlaylistSongsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistSongsTable, PlaylistSong> {
  $$PlaylistSongsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_songs__playlist_id__playlists__id');

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

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('playlist_songs__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StopMarksTable, List<StopMark>>
  _stopMarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stopMarks,
    aliasName: 'playlist_songs__id__stop_marks__playlist_song_id',
  );

  $$StopMarksTableProcessedTableManager get stopMarksRefs {
    final manager = $$StopMarksTableTableManager(
      $_db,
      $_db.stopMarks,
    ).filter((f) => f.playlistSongId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stopMarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistSongsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableFilterComposer({
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

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scrollSpeed => $composableBuilder(
    column: $table.scrollSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stopMarksOverride => $composableBuilder(
    column: $table.stopMarksOverride,
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

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stopMarksRefs(
    Expression<bool> Function($$StopMarksTableFilterComposer f) f,
  ) {
    final $$StopMarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopMarks,
      getReferencedColumn: (t) => t.playlistSongId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopMarksTableFilterComposer(
            $db: $db,
            $table: $db.stopMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistSongsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableOrderingComposer({
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

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempo => $composableBuilder(
    column: $table.tempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scrollSpeed => $composableBuilder(
    column: $table.scrollSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stopMarksOverride => $composableBuilder(
    column: $table.stopMarksOverride,
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

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistSongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistSongsTable> {
  $$PlaylistSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tempo =>
      $composableBuilder(column: $table.tempo, builder: (column) => column);

  GeneratedColumn<double> get scrollSpeed => $composableBuilder(
    column: $table.scrollSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<double> get introDuration => $composableBuilder(
    column: $table.introDuration,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get stopMarksOverride => $composableBuilder(
    column: $table.stopMarksOverride,
    builder: (column) => column,
  );

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

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stopMarksRefs<T extends Object>(
    Expression<T> Function($$StopMarksTableAnnotationComposer a) f,
  ) {
    final $$StopMarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopMarks,
      getReferencedColumn: (t) => t.playlistSongId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopMarksTableAnnotationComposer(
            $db: $db,
            $table: $db.stopMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistSongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistSongsTable,
          PlaylistSong,
          $$PlaylistSongsTableFilterComposer,
          $$PlaylistSongsTableOrderingComposer,
          $$PlaylistSongsTableAnnotationComposer,
          $$PlaylistSongsTableCreateCompanionBuilder,
          $$PlaylistSongsTableUpdateCompanionBuilder,
          (PlaylistSong, $$PlaylistSongsTableReferences),
          PlaylistSong,
          PrefetchHooks Function({
            bool playlistId,
            bool songId,
            bool stopMarksRefs,
          })
        > {
  $$PlaylistSongsTableTableManager(_$AppDatabase db, $PlaylistSongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> occurrenceId = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<int> songId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<double?> tempo = const Value.absent(),
                Value<double?> scrollSpeed = const Value.absent(),
                Value<double?> introDuration = const Value.absent(),
                Value<bool?> stopMarksOverride = const Value.absent(),
              }) => PlaylistSongsCompanion(
                id: id,
                occurrenceId: occurrenceId,
                playlistId: playlistId,
                songId: songId,
                orderIndex: orderIndex,
                tempo: tempo,
                scrollSpeed: scrollSpeed,
                introDuration: introDuration,
                stopMarksOverride: stopMarksOverride,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String occurrenceId,
                required int playlistId,
                required int songId,
                Value<int> orderIndex = const Value.absent(),
                Value<double?> tempo = const Value.absent(),
                Value<double?> scrollSpeed = const Value.absent(),
                Value<double?> introDuration = const Value.absent(),
                Value<bool?> stopMarksOverride = const Value.absent(),
              }) => PlaylistSongsCompanion.insert(
                id: id,
                occurrenceId: occurrenceId,
                playlistId: playlistId,
                songId: songId,
                orderIndex: orderIndex,
                tempo: tempo,
                scrollSpeed: scrollSpeed,
                introDuration: introDuration,
                stopMarksOverride: stopMarksOverride,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistSongsTable, PlaylistSong>(table),
                  $$PlaylistSongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistId = false, songId = false, stopMarksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (stopMarksRefs) db.stopMarks],
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
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.playlistId,
                                    referencedTable:
                                        $$PlaylistSongsTableReferences
                                            ._playlistIdTable(db),
                                    referencedColumn:
                                        $$PlaylistSongsTableReferences
                                            ._playlistIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (songId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.songId,
                                    referencedTable:
                                        $$PlaylistSongsTableReferences
                                            ._songIdTable(db),
                                    referencedColumn:
                                        $$PlaylistSongsTableReferences
                                            ._songIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stopMarksRefs)
                        await $_getPrefetchedData<
                          PlaylistSong,
                          $PlaylistSongsTable,
                          StopMark
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistSongsTableReferences
                              ._stopMarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistSongsTableReferences(
                                db,
                                table,
                                p0,
                              ).stopMarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistSongId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistSongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistSongsTable,
      PlaylistSong,
      $$PlaylistSongsTableFilterComposer,
      $$PlaylistSongsTableOrderingComposer,
      $$PlaylistSongsTableAnnotationComposer,
      $$PlaylistSongsTableCreateCompanionBuilder,
      $$PlaylistSongsTableUpdateCompanionBuilder,
      (PlaylistSong, $$PlaylistSongsTableReferences),
      PlaylistSong,
      PrefetchHooks Function({bool playlistId, bool songId, bool stopMarksRefs})
    >;
typedef $$StopMarksTableCreateCompanionBuilder =
    StopMarksCompanion Function({
      Value<int> id,
      required int songId,
      required double positionRatio,
      required int durationBars,
      Value<int?> lineIndex,
      Value<String?> lineText,
      Value<int?> playlistSongId,
    });
typedef $$StopMarksTableUpdateCompanionBuilder =
    StopMarksCompanion Function({
      Value<int> id,
      Value<int> songId,
      Value<double> positionRatio,
      Value<int> durationBars,
      Value<int?> lineIndex,
      Value<String?> lineText,
      Value<int?> playlistSongId,
    });

final class $$StopMarksTableReferences
    extends BaseReferences<_$AppDatabase, $StopMarksTable, StopMark> {
  $$StopMarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('stop_marks__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlaylistSongsTable _playlistSongIdTable(_$AppDatabase db) => db
      .playlistSongs
      .createAlias('stop_marks__playlist_song_id__playlist_songs__id');

  $$PlaylistSongsTableProcessedTableManager? get playlistSongId {
    final $_column = $_itemColumn<int>('playlist_song_id');
    if ($_column == null) return null;
    final manager = $$PlaylistSongsTableTableManager(
      $_db,
      $_db.playlistSongs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistSongIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StopMarksTableFilterComposer
    extends Composer<_$AppDatabase, $StopMarksTable> {
  $$StopMarksTableFilterComposer({
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

  ColumnFilters<double> get positionRatio => $composableBuilder(
    column: $table.positionRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationBars => $composableBuilder(
    column: $table.durationBars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineIndex => $composableBuilder(
    column: $table.lineIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineText => $composableBuilder(
    column: $table.lineText,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaylistSongsTableFilterComposer get playlistSongId {
    final $$PlaylistSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistSongId,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableFilterComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopMarksTableOrderingComposer
    extends Composer<_$AppDatabase, $StopMarksTable> {
  $$StopMarksTableOrderingComposer({
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

  ColumnOrderings<double> get positionRatio => $composableBuilder(
    column: $table.positionRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationBars => $composableBuilder(
    column: $table.durationBars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineIndex => $composableBuilder(
    column: $table.lineIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineText => $composableBuilder(
    column: $table.lineText,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaylistSongsTableOrderingComposer get playlistSongId {
    final $$PlaylistSongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistSongId,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableOrderingComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopMarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StopMarksTable> {
  $$StopMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get positionRatio => $composableBuilder(
    column: $table.positionRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationBars => $composableBuilder(
    column: $table.durationBars,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineIndex =>
      $composableBuilder(column: $table.lineIndex, builder: (column) => column);

  GeneratedColumn<String> get lineText =>
      $composableBuilder(column: $table.lineText, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaylistSongsTableAnnotationComposer get playlistSongId {
    final $$PlaylistSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistSongId,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopMarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StopMarksTable,
          StopMark,
          $$StopMarksTableFilterComposer,
          $$StopMarksTableOrderingComposer,
          $$StopMarksTableAnnotationComposer,
          $$StopMarksTableCreateCompanionBuilder,
          $$StopMarksTableUpdateCompanionBuilder,
          (StopMark, $$StopMarksTableReferences),
          StopMark,
          PrefetchHooks Function({bool songId, bool playlistSongId})
        > {
  $$StopMarksTableTableManager(_$AppDatabase db, $StopMarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StopMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StopMarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StopMarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> songId = const Value.absent(),
                Value<double> positionRatio = const Value.absent(),
                Value<int> durationBars = const Value.absent(),
                Value<int?> lineIndex = const Value.absent(),
                Value<String?> lineText = const Value.absent(),
                Value<int?> playlistSongId = const Value.absent(),
              }) => StopMarksCompanion(
                id: id,
                songId: songId,
                positionRatio: positionRatio,
                durationBars: durationBars,
                lineIndex: lineIndex,
                lineText: lineText,
                playlistSongId: playlistSongId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int songId,
                required double positionRatio,
                required int durationBars,
                Value<int?> lineIndex = const Value.absent(),
                Value<String?> lineText = const Value.absent(),
                Value<int?> playlistSongId = const Value.absent(),
              }) => StopMarksCompanion.insert(
                id: id,
                songId: songId,
                positionRatio: positionRatio,
                durationBars: durationBars,
                lineIndex: lineIndex,
                lineText: lineText,
                playlistSongId: playlistSongId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StopMarksTable, StopMark>(table),
                  $$StopMarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false, playlistSongId = false}) {
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
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$StopMarksTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$StopMarksTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (playlistSongId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistSongId,
                                referencedTable: $$StopMarksTableReferences
                                    ._playlistSongIdTable(db),
                                referencedColumn: $$StopMarksTableReferences
                                    ._playlistSongIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$StopMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StopMarksTable,
      StopMark,
      $$StopMarksTableFilterComposer,
      $$StopMarksTableOrderingComposer,
      $$StopMarksTableAnnotationComposer,
      $$StopMarksTableCreateCompanionBuilder,
      $$StopMarksTableUpdateCompanionBuilder,
      (StopMark, $$StopMarksTableReferences),
      StopMark,
      PrefetchHooks Function({bool songId, bool playlistSongId})
    >;
typedef $$CustomStringsTableCreateCompanionBuilder =
    CustomStringsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$CustomStringsTableUpdateCompanionBuilder =
    CustomStringsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$CustomStringsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomStringsTable> {
  $$CustomStringsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomStringsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomStringsTable> {
  $$CustomStringsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomStringsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomStringsTable> {
  $$CustomStringsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$CustomStringsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomStringsTable,
          CustomString,
          $$CustomStringsTableFilterComposer,
          $$CustomStringsTableOrderingComposer,
          $$CustomStringsTableAnnotationComposer,
          $$CustomStringsTableCreateCompanionBuilder,
          $$CustomStringsTableUpdateCompanionBuilder,
          (
            CustomString,
            BaseReferences<_$AppDatabase, $CustomStringsTable, CustomString>,
          ),
          CustomString,
          PrefetchHooks Function()
        > {
  $$CustomStringsTableTableManager(_$AppDatabase db, $CustomStringsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomStringsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomStringsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomStringsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  CustomStringsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => CustomStringsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomStringsTable, CustomString>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomStringsTable,
                    CustomString
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomStringsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomStringsTable,
      CustomString,
      $$CustomStringsTableFilterComposer,
      $$CustomStringsTableOrderingComposer,
      $$CustomStringsTableAnnotationComposer,
      $$CustomStringsTableCreateCompanionBuilder,
      $$CustomStringsTableUpdateCompanionBuilder,
      (
        CustomString,
        BaseReferences<_$AppDatabase, $CustomStringsTable, CustomString>,
      ),
      CustomString,
      PrefetchHooks Function()
    >;
typedef $$DiacriticMappingsTableCreateCompanionBuilder =
    DiacriticMappingsCompanion Function({
      required String normKey,
      required String corrected,
      Value<int> rowid,
    });
typedef $$DiacriticMappingsTableUpdateCompanionBuilder =
    DiacriticMappingsCompanion Function({
      Value<String> normKey,
      Value<String> corrected,
      Value<int> rowid,
    });

class $$DiacriticMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $DiacriticMappingsTable> {
  $$DiacriticMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get normKey => $composableBuilder(
    column: $table.normKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get corrected => $composableBuilder(
    column: $table.corrected,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiacriticMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiacriticMappingsTable> {
  $$DiacriticMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get normKey => $composableBuilder(
    column: $table.normKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get corrected => $composableBuilder(
    column: $table.corrected,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiacriticMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiacriticMappingsTable> {
  $$DiacriticMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get normKey =>
      $composableBuilder(column: $table.normKey, builder: (column) => column);

  GeneratedColumn<String> get corrected =>
      $composableBuilder(column: $table.corrected, builder: (column) => column);
}

class $$DiacriticMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiacriticMappingsTable,
          DiacriticMappingEntry,
          $$DiacriticMappingsTableFilterComposer,
          $$DiacriticMappingsTableOrderingComposer,
          $$DiacriticMappingsTableAnnotationComposer,
          $$DiacriticMappingsTableCreateCompanionBuilder,
          $$DiacriticMappingsTableUpdateCompanionBuilder,
          (
            DiacriticMappingEntry,
            BaseReferences<
              _$AppDatabase,
              $DiacriticMappingsTable,
              DiacriticMappingEntry
            >,
          ),
          DiacriticMappingEntry,
          PrefetchHooks Function()
        > {
  $$DiacriticMappingsTableTableManager(
    _$AppDatabase db,
    $DiacriticMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiacriticMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiacriticMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiacriticMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> normKey = const Value.absent(),
                Value<String> corrected = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiacriticMappingsCompanion(
                normKey: normKey,
                corrected: corrected,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String normKey,
                required String corrected,
                Value<int> rowid = const Value.absent(),
              }) => DiacriticMappingsCompanion.insert(
                normKey: normKey,
                corrected: corrected,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiacriticMappingsTable, DiacriticMappingEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DiacriticMappingsTable,
                    DiacriticMappingEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiacriticMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiacriticMappingsTable,
      DiacriticMappingEntry,
      $$DiacriticMappingsTableFilterComposer,
      $$DiacriticMappingsTableOrderingComposer,
      $$DiacriticMappingsTableAnnotationComposer,
      $$DiacriticMappingsTableCreateCompanionBuilder,
      $$DiacriticMappingsTableUpdateCompanionBuilder,
      (
        DiacriticMappingEntry,
        BaseReferences<
          _$AppDatabase,
          $DiacriticMappingsTable,
          DiacriticMappingEntry
        >,
      ),
      DiacriticMappingEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistSongsTableTableManager get playlistSongs =>
      $$PlaylistSongsTableTableManager(_db, _db.playlistSongs);
  $$StopMarksTableTableManager get stopMarks =>
      $$StopMarksTableTableManager(_db, _db.stopMarks);
  $$CustomStringsTableTableManager get customStrings =>
      $$CustomStringsTableTableManager(_db, _db.customStrings);
  $$DiacriticMappingsTableTableManager get diacriticMappings =>
      $$DiacriticMappingsTableTableManager(_db, _db.diacriticMappings);
}
