// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $OfflineDocumentsTable extends OfflineDocuments
    with TableInfo<$OfflineDocumentsTable, OfflineDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessKeyMeta = const VerificationMeta(
    'accessKey',
  );
  @override
  late final GeneratedColumn<String> accessKey = GeneratedColumn<String>(
    'access_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<int> model = GeneratedColumn<int>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xmlMeta = const VerificationMeta('xml');
  @override
  late final GeneratedColumn<String> xml = GeneratedColumn<String>(
    'xml',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xmlSha256Meta = const VerificationMeta(
    'xmlSha256',
  );
  @override
  late final GeneratedColumn<String> xmlSha256 = GeneratedColumn<String>(
    'xml_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deadlineAtMeta = const VerificationMeta(
    'deadlineAt',
  );
  @override
  late final GeneratedColumn<DateTime> deadlineAt = GeneratedColumn<DateTime>(
    'deadline_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transmittingAtMeta = const VerificationMeta(
    'transmittingAt',
  );
  @override
  late final GeneratedColumn<DateTime> transmittingAt =
      GeneratedColumn<DateTime>(
        'transmitting_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accessKey,
    model,
    xml,
    xmlSha256,
    state,
    attempts,
    createdAt,
    lastError,
    nextAttemptAt,
    deadlineAt,
    transmittingAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('access_key')) {
      context.handle(
        _accessKeyMeta,
        accessKey.isAcceptableOrUnknown(data['access_key']!, _accessKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accessKeyMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('xml')) {
      context.handle(
        _xmlMeta,
        xml.isAcceptableOrUnknown(data['xml']!, _xmlMeta),
      );
    } else if (isInserting) {
      context.missing(_xmlMeta);
    }
    if (data.containsKey('xml_sha256')) {
      context.handle(
        _xmlSha256Meta,
        xmlSha256.isAcceptableOrUnknown(data['xml_sha256']!, _xmlSha256Meta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('deadline_at')) {
      context.handle(
        _deadlineAtMeta,
        deadlineAt.isAcceptableOrUnknown(data['deadline_at']!, _deadlineAtMeta),
      );
    }
    if (data.containsKey('transmitting_at')) {
      context.handle(
        _transmittingAtMeta,
        transmittingAt.isAcceptableOrUnknown(
          data['transmitting_at']!,
          _transmittingAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accessKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_key'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model'],
      )!,
      xml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xml'],
      )!,
      xmlSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xml_sha256'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      deadlineAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline_at'],
      ),
      transmittingAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transmitting_at'],
      ),
    );
  }

  @override
  $OfflineDocumentsTable createAlias(String alias) {
    return $OfflineDocumentsTable(attachedDatabase, alias);
  }
}

class OfflineDocument extends DataClass implements Insertable<OfflineDocument> {
  /// Identificador idempotente.
  final String id;

  /// Chave de acesso fiscal.
  final String accessKey;

  /// Modelo fiscal.
  final int model;

  /// XML assinado persistido.
  final String xml;

  /// Digest SHA-256 do XML para detectar corrupção local.
  final String? xmlSha256;

  /// Índice de [FiscalDocumentState].
  final int state;

  /// Número de tentativas de transmissão.
  final int attempts;

  /// Data de criação.
  final DateTime createdAt;

  /// Último erro não secreto.
  final String? lastError;

  /// Próxima tentativa agendada.
  final DateTime? nextAttemptAt;

  /// Prazo legal para transmissão do documento.
  final DateTime? deadlineAt;

  /// Momento da tentativa, usado para recuperar reinícios inesperados.
  final DateTime? transmittingAt;
  const OfflineDocument({
    required this.id,
    required this.accessKey,
    required this.model,
    required this.xml,
    this.xmlSha256,
    required this.state,
    required this.attempts,
    required this.createdAt,
    this.lastError,
    this.nextAttemptAt,
    this.deadlineAt,
    this.transmittingAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['access_key'] = Variable<String>(accessKey);
    map['model'] = Variable<int>(model);
    map['xml'] = Variable<String>(xml);
    if (!nullToAbsent || xmlSha256 != null) {
      map['xml_sha256'] = Variable<String>(xmlSha256);
    }
    map['state'] = Variable<int>(state);
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || deadlineAt != null) {
      map['deadline_at'] = Variable<DateTime>(deadlineAt);
    }
    if (!nullToAbsent || transmittingAt != null) {
      map['transmitting_at'] = Variable<DateTime>(transmittingAt);
    }
    return map;
  }

  OfflineDocumentsCompanion toCompanion(bool nullToAbsent) {
    return OfflineDocumentsCompanion(
      id: Value(id),
      accessKey: Value(accessKey),
      model: Value(model),
      xml: Value(xml),
      xmlSha256: xmlSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(xmlSha256),
      state: Value(state),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      deadlineAt: deadlineAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineAt),
      transmittingAt: transmittingAt == null && nullToAbsent
          ? const Value.absent()
          : Value(transmittingAt),
    );
  }

  factory OfflineDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineDocument(
      id: serializer.fromJson<String>(json['id']),
      accessKey: serializer.fromJson<String>(json['accessKey']),
      model: serializer.fromJson<int>(json['model']),
      xml: serializer.fromJson<String>(json['xml']),
      xmlSha256: serializer.fromJson<String?>(json['xmlSha256']),
      state: serializer.fromJson<int>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      deadlineAt: serializer.fromJson<DateTime?>(json['deadlineAt']),
      transmittingAt: serializer.fromJson<DateTime?>(json['transmittingAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accessKey': serializer.toJson<String>(accessKey),
      'model': serializer.toJson<int>(model),
      'xml': serializer.toJson<String>(xml),
      'xmlSha256': serializer.toJson<String?>(xmlSha256),
      'state': serializer.toJson<int>(state),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastError': serializer.toJson<String?>(lastError),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'deadlineAt': serializer.toJson<DateTime?>(deadlineAt),
      'transmittingAt': serializer.toJson<DateTime?>(transmittingAt),
    };
  }

  OfflineDocument copyWith({
    String? id,
    String? accessKey,
    int? model,
    String? xml,
    Value<String?> xmlSha256 = const Value.absent(),
    int? state,
    int? attempts,
    DateTime? createdAt,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<DateTime?> deadlineAt = const Value.absent(),
    Value<DateTime?> transmittingAt = const Value.absent(),
  }) => OfflineDocument(
    id: id ?? this.id,
    accessKey: accessKey ?? this.accessKey,
    model: model ?? this.model,
    xml: xml ?? this.xml,
    xmlSha256: xmlSha256.present ? xmlSha256.value : this.xmlSha256,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    deadlineAt: deadlineAt.present ? deadlineAt.value : this.deadlineAt,
    transmittingAt: transmittingAt.present
        ? transmittingAt.value
        : this.transmittingAt,
  );
  OfflineDocument copyWithCompanion(OfflineDocumentsCompanion data) {
    return OfflineDocument(
      id: data.id.present ? data.id.value : this.id,
      accessKey: data.accessKey.present ? data.accessKey.value : this.accessKey,
      model: data.model.present ? data.model.value : this.model,
      xml: data.xml.present ? data.xml.value : this.xml,
      xmlSha256: data.xmlSha256.present ? data.xmlSha256.value : this.xmlSha256,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      deadlineAt: data.deadlineAt.present
          ? data.deadlineAt.value
          : this.deadlineAt,
      transmittingAt: data.transmittingAt.present
          ? data.transmittingAt.value
          : this.transmittingAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineDocument(')
          ..write('id: $id, ')
          ..write('accessKey: $accessKey, ')
          ..write('model: $model, ')
          ..write('xml: $xml, ')
          ..write('xmlSha256: $xmlSha256, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('transmittingAt: $transmittingAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accessKey,
    model,
    xml,
    xmlSha256,
    state,
    attempts,
    createdAt,
    lastError,
    nextAttemptAt,
    deadlineAt,
    transmittingAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineDocument &&
          other.id == this.id &&
          other.accessKey == this.accessKey &&
          other.model == this.model &&
          other.xml == this.xml &&
          other.xmlSha256 == this.xmlSha256 &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt &&
          other.lastError == this.lastError &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.deadlineAt == this.deadlineAt &&
          other.transmittingAt == this.transmittingAt);
}

class OfflineDocumentsCompanion extends UpdateCompanion<OfflineDocument> {
  final Value<String> id;
  final Value<String> accessKey;
  final Value<int> model;
  final Value<String> xml;
  final Value<String?> xmlSha256;
  final Value<int> state;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<String?> lastError;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime?> deadlineAt;
  final Value<DateTime?> transmittingAt;
  final Value<int> rowid;
  const OfflineDocumentsCompanion({
    this.id = const Value.absent(),
    this.accessKey = const Value.absent(),
    this.model = const Value.absent(),
    this.xml = const Value.absent(),
    this.xmlSha256 = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    this.transmittingAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineDocumentsCompanion.insert({
    required String id,
    required String accessKey,
    required int model,
    required String xml,
    this.xmlSha256 = const Value.absent(),
    required int state,
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    this.transmittingAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accessKey = Value(accessKey),
       model = Value(model),
       xml = Value(xml),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<OfflineDocument> custom({
    Expression<String>? id,
    Expression<String>? accessKey,
    Expression<int>? model,
    Expression<String>? xml,
    Expression<String>? xmlSha256,
    Expression<int>? state,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
    Expression<String>? lastError,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? deadlineAt,
    Expression<DateTime>? transmittingAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accessKey != null) 'access_key': accessKey,
      if (model != null) 'model': model,
      if (xml != null) 'xml': xml,
      if (xmlSha256 != null) 'xml_sha256': xmlSha256,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (lastError != null) 'last_error': lastError,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (deadlineAt != null) 'deadline_at': deadlineAt,
      if (transmittingAt != null) 'transmitting_at': transmittingAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? accessKey,
    Value<int>? model,
    Value<String>? xml,
    Value<String?>? xmlSha256,
    Value<int>? state,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
    Value<String?>? lastError,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime?>? deadlineAt,
    Value<DateTime?>? transmittingAt,
    Value<int>? rowid,
  }) {
    return OfflineDocumentsCompanion(
      id: id ?? this.id,
      accessKey: accessKey ?? this.accessKey,
      model: model ?? this.model,
      xml: xml ?? this.xml,
      xmlSha256: xmlSha256 ?? this.xmlSha256,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      transmittingAt: transmittingAt ?? this.transmittingAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accessKey.present) {
      map['access_key'] = Variable<String>(accessKey.value);
    }
    if (model.present) {
      map['model'] = Variable<int>(model.value);
    }
    if (xml.present) {
      map['xml'] = Variable<String>(xml.value);
    }
    if (xmlSha256.present) {
      map['xml_sha256'] = Variable<String>(xmlSha256.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (deadlineAt.present) {
      map['deadline_at'] = Variable<DateTime>(deadlineAt.value);
    }
    if (transmittingAt.present) {
      map['transmitting_at'] = Variable<DateTime>(transmittingAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('accessKey: $accessKey, ')
          ..write('model: $model, ')
          ..write('xml: $xml, ')
          ..write('xmlSha256: $xmlSha256, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('transmittingAt: $transmittingAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiscalNumberSequencesTable extends FiscalNumberSequences
    with TableInfo<$FiscalNumberSequencesTable, FiscalNumberSequence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiscalNumberSequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cUfMeta = const VerificationMeta('cUf');
  @override
  late final GeneratedColumn<String> cUf = GeneratedColumn<String>(
    'c_uf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issuerCnpjMeta = const VerificationMeta(
    'issuerCnpj',
  );
  @override
  late final GeneratedColumn<String> issuerCnpj = GeneratedColumn<String>(
    'issuer_cnpj',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<int> model = GeneratedColumn<int>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<int> series = GeneratedColumn<int>(
    'series',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextNumberMeta = const VerificationMeta(
    'nextNumber',
  );
  @override
  late final GeneratedColumn<int> nextNumber = GeneratedColumn<int>(
    'next_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    cUf,
    issuerCnpj,
    model,
    series,
    nextNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fiscal_number_sequences';
  @override
  VerificationContext validateIntegrity(
    Insertable<FiscalNumberSequence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('c_uf')) {
      context.handle(
        _cUfMeta,
        cUf.isAcceptableOrUnknown(data['c_uf']!, _cUfMeta),
      );
    } else if (isInserting) {
      context.missing(_cUfMeta);
    }
    if (data.containsKey('issuer_cnpj')) {
      context.handle(
        _issuerCnpjMeta,
        issuerCnpj.isAcceptableOrUnknown(data['issuer_cnpj']!, _issuerCnpjMeta),
      );
    } else if (isInserting) {
      context.missing(_issuerCnpjMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesMeta);
    }
    if (data.containsKey('next_number')) {
      context.handle(
        _nextNumberMeta,
        nextNumber.isAcceptableOrUnknown(data['next_number']!, _nextNumberMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cUf, issuerCnpj, model, series};
  @override
  FiscalNumberSequence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FiscalNumberSequence(
      cUf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c_uf'],
      )!,
      issuerCnpj: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuer_cnpj'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model'],
      )!,
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series'],
      )!,
      nextNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_number'],
      )!,
    );
  }

  @override
  $FiscalNumberSequencesTable createAlias(String alias) {
    return $FiscalNumberSequencesTable(attachedDatabase, alias);
  }
}

class FiscalNumberSequence extends DataClass
    implements Insertable<FiscalNumberSequence> {
  /// UF em dois dígitos.
  final String cUf;

  /// CNPJ do emitente sem pontuação.
  final String issuerCnpj;

  /// Modelo 55 ou 65.
  final int model;

  /// Série fiscal.
  final int series;

  /// Próximo número ainda não reservado.
  final int nextNumber;
  const FiscalNumberSequence({
    required this.cUf,
    required this.issuerCnpj,
    required this.model,
    required this.series,
    required this.nextNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['c_uf'] = Variable<String>(cUf);
    map['issuer_cnpj'] = Variable<String>(issuerCnpj);
    map['model'] = Variable<int>(model);
    map['series'] = Variable<int>(series);
    map['next_number'] = Variable<int>(nextNumber);
    return map;
  }

  FiscalNumberSequencesCompanion toCompanion(bool nullToAbsent) {
    return FiscalNumberSequencesCompanion(
      cUf: Value(cUf),
      issuerCnpj: Value(issuerCnpj),
      model: Value(model),
      series: Value(series),
      nextNumber: Value(nextNumber),
    );
  }

  factory FiscalNumberSequence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FiscalNumberSequence(
      cUf: serializer.fromJson<String>(json['cUf']),
      issuerCnpj: serializer.fromJson<String>(json['issuerCnpj']),
      model: serializer.fromJson<int>(json['model']),
      series: serializer.fromJson<int>(json['series']),
      nextNumber: serializer.fromJson<int>(json['nextNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cUf': serializer.toJson<String>(cUf),
      'issuerCnpj': serializer.toJson<String>(issuerCnpj),
      'model': serializer.toJson<int>(model),
      'series': serializer.toJson<int>(series),
      'nextNumber': serializer.toJson<int>(nextNumber),
    };
  }

  FiscalNumberSequence copyWith({
    String? cUf,
    String? issuerCnpj,
    int? model,
    int? series,
    int? nextNumber,
  }) => FiscalNumberSequence(
    cUf: cUf ?? this.cUf,
    issuerCnpj: issuerCnpj ?? this.issuerCnpj,
    model: model ?? this.model,
    series: series ?? this.series,
    nextNumber: nextNumber ?? this.nextNumber,
  );
  FiscalNumberSequence copyWithCompanion(FiscalNumberSequencesCompanion data) {
    return FiscalNumberSequence(
      cUf: data.cUf.present ? data.cUf.value : this.cUf,
      issuerCnpj: data.issuerCnpj.present
          ? data.issuerCnpj.value
          : this.issuerCnpj,
      model: data.model.present ? data.model.value : this.model,
      series: data.series.present ? data.series.value : this.series,
      nextNumber: data.nextNumber.present
          ? data.nextNumber.value
          : this.nextNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FiscalNumberSequence(')
          ..write('cUf: $cUf, ')
          ..write('issuerCnpj: $issuerCnpj, ')
          ..write('model: $model, ')
          ..write('series: $series, ')
          ..write('nextNumber: $nextNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cUf, issuerCnpj, model, series, nextNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FiscalNumberSequence &&
          other.cUf == this.cUf &&
          other.issuerCnpj == this.issuerCnpj &&
          other.model == this.model &&
          other.series == this.series &&
          other.nextNumber == this.nextNumber);
}

class FiscalNumberSequencesCompanion
    extends UpdateCompanion<FiscalNumberSequence> {
  final Value<String> cUf;
  final Value<String> issuerCnpj;
  final Value<int> model;
  final Value<int> series;
  final Value<int> nextNumber;
  final Value<int> rowid;
  const FiscalNumberSequencesCompanion({
    this.cUf = const Value.absent(),
    this.issuerCnpj = const Value.absent(),
    this.model = const Value.absent(),
    this.series = const Value.absent(),
    this.nextNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FiscalNumberSequencesCompanion.insert({
    required String cUf,
    required String issuerCnpj,
    required int model,
    required int series,
    this.nextNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cUf = Value(cUf),
       issuerCnpj = Value(issuerCnpj),
       model = Value(model),
       series = Value(series);
  static Insertable<FiscalNumberSequence> custom({
    Expression<String>? cUf,
    Expression<String>? issuerCnpj,
    Expression<int>? model,
    Expression<int>? series,
    Expression<int>? nextNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cUf != null) 'c_uf': cUf,
      if (issuerCnpj != null) 'issuer_cnpj': issuerCnpj,
      if (model != null) 'model': model,
      if (series != null) 'series': series,
      if (nextNumber != null) 'next_number': nextNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FiscalNumberSequencesCompanion copyWith({
    Value<String>? cUf,
    Value<String>? issuerCnpj,
    Value<int>? model,
    Value<int>? series,
    Value<int>? nextNumber,
    Value<int>? rowid,
  }) {
    return FiscalNumberSequencesCompanion(
      cUf: cUf ?? this.cUf,
      issuerCnpj: issuerCnpj ?? this.issuerCnpj,
      model: model ?? this.model,
      series: series ?? this.series,
      nextNumber: nextNumber ?? this.nextNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cUf.present) {
      map['c_uf'] = Variable<String>(cUf.value);
    }
    if (issuerCnpj.present) {
      map['issuer_cnpj'] = Variable<String>(issuerCnpj.value);
    }
    if (model.present) {
      map['model'] = Variable<int>(model.value);
    }
    if (series.present) {
      map['series'] = Variable<int>(series.value);
    }
    if (nextNumber.present) {
      map['next_number'] = Variable<int>(nextNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiscalNumberSequencesCompanion(')
          ..write('cUf: $cUf, ')
          ..write('issuerCnpj: $issuerCnpj, ')
          ..write('model: $model, ')
          ..write('series: $series, ')
          ..write('nextNumber: $nextNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ExampleFiscalDatabase extends GeneratedDatabase {
  _$ExampleFiscalDatabase(QueryExecutor e) : super(e);
  $ExampleFiscalDatabaseManager get managers =>
      $ExampleFiscalDatabaseManager(this);
  late final $OfflineDocumentsTable offlineDocuments = $OfflineDocumentsTable(
    this,
  );
  late final $FiscalNumberSequencesTable fiscalNumberSequences =
      $FiscalNumberSequencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    offlineDocuments,
    fiscalNumberSequences,
  ];
}

typedef $$OfflineDocumentsTableCreateCompanionBuilder =
    OfflineDocumentsCompanion Function({
      required String id,
      required String accessKey,
      required int model,
      required String xml,
      Value<String?> xmlSha256,
      required int state,
      Value<int> attempts,
      required DateTime createdAt,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> deadlineAt,
      Value<DateTime?> transmittingAt,
      Value<int> rowid,
    });
typedef $$OfflineDocumentsTableUpdateCompanionBuilder =
    OfflineDocumentsCompanion Function({
      Value<String> id,
      Value<String> accessKey,
      Value<int> model,
      Value<String> xml,
      Value<String?> xmlSha256,
      Value<int> state,
      Value<int> attempts,
      Value<DateTime> createdAt,
      Value<String?> lastError,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> deadlineAt,
      Value<DateTime?> transmittingAt,
      Value<int> rowid,
    });

class $$OfflineDocumentsTableFilterComposer
    extends Composer<_$ExampleFiscalDatabase, $OfflineDocumentsTable> {
  $$OfflineDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessKey => $composableBuilder(
    column: $table.accessKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get xml => $composableBuilder(
    column: $table.xml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get xmlSha256 => $composableBuilder(
    column: $table.xmlSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transmittingAt => $composableBuilder(
    column: $table.transmittingAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineDocumentsTableOrderingComposer
    extends Composer<_$ExampleFiscalDatabase, $OfflineDocumentsTable> {
  $$OfflineDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessKey => $composableBuilder(
    column: $table.accessKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get xml => $composableBuilder(
    column: $table.xml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get xmlSha256 => $composableBuilder(
    column: $table.xmlSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transmittingAt => $composableBuilder(
    column: $table.transmittingAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineDocumentsTableAnnotationComposer
    extends Composer<_$ExampleFiscalDatabase, $OfflineDocumentsTable> {
  $$OfflineDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accessKey =>
      $composableBuilder(column: $table.accessKey, builder: (column) => column);

  GeneratedColumn<int> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get xml =>
      $composableBuilder(column: $table.xml, builder: (column) => column);

  GeneratedColumn<String> get xmlSha256 =>
      $composableBuilder(column: $table.xmlSha256, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get transmittingAt => $composableBuilder(
    column: $table.transmittingAt,
    builder: (column) => column,
  );
}

class $$OfflineDocumentsTableTableManager
    extends
        RootTableManager<
          _$ExampleFiscalDatabase,
          $OfflineDocumentsTable,
          OfflineDocument,
          $$OfflineDocumentsTableFilterComposer,
          $$OfflineDocumentsTableOrderingComposer,
          $$OfflineDocumentsTableAnnotationComposer,
          $$OfflineDocumentsTableCreateCompanionBuilder,
          $$OfflineDocumentsTableUpdateCompanionBuilder,
          (
            OfflineDocument,
            BaseReferences<
              _$ExampleFiscalDatabase,
              $OfflineDocumentsTable,
              OfflineDocument
            >,
          ),
          OfflineDocument,
          PrefetchHooks Function()
        > {
  $$OfflineDocumentsTableTableManager(
    _$ExampleFiscalDatabase db,
    $OfflineDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accessKey = const Value.absent(),
                Value<int> model = const Value.absent(),
                Value<String> xml = const Value.absent(),
                Value<String?> xmlSha256 = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> deadlineAt = const Value.absent(),
                Value<DateTime?> transmittingAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineDocumentsCompanion(
                id: id,
                accessKey: accessKey,
                model: model,
                xml: xml,
                xmlSha256: xmlSha256,
                state: state,
                attempts: attempts,
                createdAt: createdAt,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                deadlineAt: deadlineAt,
                transmittingAt: transmittingAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accessKey,
                required int model,
                required String xml,
                Value<String?> xmlSha256 = const Value.absent(),
                required int state,
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> deadlineAt = const Value.absent(),
                Value<DateTime?> transmittingAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineDocumentsCompanion.insert(
                id: id,
                accessKey: accessKey,
                model: model,
                xml: xml,
                xmlSha256: xmlSha256,
                state: state,
                attempts: attempts,
                createdAt: createdAt,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                deadlineAt: deadlineAt,
                transmittingAt: transmittingAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflineDocumentsTable, OfflineDocument>(table),
                  BaseReferences<
                    _$ExampleFiscalDatabase,
                    $OfflineDocumentsTable,
                    OfflineDocument
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$ExampleFiscalDatabase,
      $OfflineDocumentsTable,
      OfflineDocument,
      $$OfflineDocumentsTableFilterComposer,
      $$OfflineDocumentsTableOrderingComposer,
      $$OfflineDocumentsTableAnnotationComposer,
      $$OfflineDocumentsTableCreateCompanionBuilder,
      $$OfflineDocumentsTableUpdateCompanionBuilder,
      (
        OfflineDocument,
        BaseReferences<
          _$ExampleFiscalDatabase,
          $OfflineDocumentsTable,
          OfflineDocument
        >,
      ),
      OfflineDocument,
      PrefetchHooks Function()
    >;
typedef $$FiscalNumberSequencesTableCreateCompanionBuilder =
    FiscalNumberSequencesCompanion Function({
      required String cUf,
      required String issuerCnpj,
      required int model,
      required int series,
      Value<int> nextNumber,
      Value<int> rowid,
    });
typedef $$FiscalNumberSequencesTableUpdateCompanionBuilder =
    FiscalNumberSequencesCompanion Function({
      Value<String> cUf,
      Value<String> issuerCnpj,
      Value<int> model,
      Value<int> series,
      Value<int> nextNumber,
      Value<int> rowid,
    });

class $$FiscalNumberSequencesTableFilterComposer
    extends Composer<_$ExampleFiscalDatabase, $FiscalNumberSequencesTable> {
  $$FiscalNumberSequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cUf => $composableBuilder(
    column: $table.cUf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuerCnpj => $composableBuilder(
    column: $table.issuerCnpj,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FiscalNumberSequencesTableOrderingComposer
    extends Composer<_$ExampleFiscalDatabase, $FiscalNumberSequencesTable> {
  $$FiscalNumberSequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cUf => $composableBuilder(
    column: $table.cUf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuerCnpj => $composableBuilder(
    column: $table.issuerCnpj,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FiscalNumberSequencesTableAnnotationComposer
    extends Composer<_$ExampleFiscalDatabase, $FiscalNumberSequencesTable> {
  $$FiscalNumberSequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cUf =>
      $composableBuilder(column: $table.cUf, builder: (column) => column);

  GeneratedColumn<String> get issuerCnpj => $composableBuilder(
    column: $table.issuerCnpj,
    builder: (column) => column,
  );

  GeneratedColumn<int> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => column,
  );
}

class $$FiscalNumberSequencesTableTableManager
    extends
        RootTableManager<
          _$ExampleFiscalDatabase,
          $FiscalNumberSequencesTable,
          FiscalNumberSequence,
          $$FiscalNumberSequencesTableFilterComposer,
          $$FiscalNumberSequencesTableOrderingComposer,
          $$FiscalNumberSequencesTableAnnotationComposer,
          $$FiscalNumberSequencesTableCreateCompanionBuilder,
          $$FiscalNumberSequencesTableUpdateCompanionBuilder,
          (
            FiscalNumberSequence,
            BaseReferences<
              _$ExampleFiscalDatabase,
              $FiscalNumberSequencesTable,
              FiscalNumberSequence
            >,
          ),
          FiscalNumberSequence,
          PrefetchHooks Function()
        > {
  $$FiscalNumberSequencesTableTableManager(
    _$ExampleFiscalDatabase db,
    $FiscalNumberSequencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiscalNumberSequencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FiscalNumberSequencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FiscalNumberSequencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cUf = const Value.absent(),
                Value<String> issuerCnpj = const Value.absent(),
                Value<int> model = const Value.absent(),
                Value<int> series = const Value.absent(),
                Value<int> nextNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalNumberSequencesCompanion(
                cUf: cUf,
                issuerCnpj: issuerCnpj,
                model: model,
                series: series,
                nextNumber: nextNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cUf,
                required String issuerCnpj,
                required int model,
                required int series,
                Value<int> nextNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalNumberSequencesCompanion.insert(
                cUf: cUf,
                issuerCnpj: issuerCnpj,
                model: model,
                series: series,
                nextNumber: nextNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $FiscalNumberSequencesTable,
                    FiscalNumberSequence
                  >(table),
                  BaseReferences<
                    _$ExampleFiscalDatabase,
                    $FiscalNumberSequencesTable,
                    FiscalNumberSequence
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FiscalNumberSequencesTableProcessedTableManager =
    ProcessedTableManager<
      _$ExampleFiscalDatabase,
      $FiscalNumberSequencesTable,
      FiscalNumberSequence,
      $$FiscalNumberSequencesTableFilterComposer,
      $$FiscalNumberSequencesTableOrderingComposer,
      $$FiscalNumberSequencesTableAnnotationComposer,
      $$FiscalNumberSequencesTableCreateCompanionBuilder,
      $$FiscalNumberSequencesTableUpdateCompanionBuilder,
      (
        FiscalNumberSequence,
        BaseReferences<
          _$ExampleFiscalDatabase,
          $FiscalNumberSequencesTable,
          FiscalNumberSequence
        >,
      ),
      FiscalNumberSequence,
      PrefetchHooks Function()
    >;

class $ExampleFiscalDatabaseManager {
  final _$ExampleFiscalDatabase _db;
  $ExampleFiscalDatabaseManager(this._db);
  $$OfflineDocumentsTableTableManager get offlineDocuments =>
      $$OfflineDocumentsTableTableManager(_db, _db.offlineDocuments);
  $$FiscalNumberSequencesTableTableManager get fiscalNumberSequences =>
      $$FiscalNumberSequencesTableTableManager(_db, _db.fiscalNumberSequences);
}
