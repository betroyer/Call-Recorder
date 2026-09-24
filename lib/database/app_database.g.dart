// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SmsTemplatesTable extends SmsTemplates
    with TableInfo<$SmsTemplatesTable, SmsTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmsTemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, body, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sms_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<SmsTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SmsTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmsTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SmsTemplatesTable createAlias(String alias) {
    return $SmsTemplatesTable(attachedDatabase, alias);
  }
}

class SmsTemplate extends DataClass implements Insertable<SmsTemplate> {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  const SmsTemplate({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SmsTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SmsTemplatesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      createdAt: Value(createdAt),
    );
  }

  factory SmsTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmsTemplate(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SmsTemplate copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? createdAt,
  }) => SmsTemplate(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
  );
  SmsTemplate copyWithCompanion(SmsTemplatesCompanion data) {
    return SmsTemplate(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmsTemplate(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, body, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmsTemplate &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.createdAt == this.createdAt);
}

class SmsTemplatesCompanion extends UpdateCompanion<SmsTemplate> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime> createdAt;
  const SmsTemplatesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SmsTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String body,
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       body = Value(body);
  static Insertable<SmsTemplate> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SmsTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime>? createdAt,
  }) {
    return SmsTemplatesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmsTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BlastJobsTable extends BlastJobs
    with TableInfo<$BlastJobsTable, BlastJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlastJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Low'),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sentMeta = const VerificationMeta('sent');
  @override
  late final GeneratedColumn<int> sent = GeneratedColumn<int>(
    'sent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<int> failed = GeneratedColumn<int>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cancelledMeta = const VerificationMeta(
    'cancelled',
  );
  @override
  late final GeneratedColumn<bool> cancelled = GeneratedColumn<bool>(
    'cancelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cancelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('done'),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    body,
    priority,
    total,
    sent,
    failed,
    cancelled,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blast_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlastJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('sent')) {
      context.handle(
        _sentMeta,
        sent.isAcceptableOrUnknown(data['sent']!, _sentMeta),
      );
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    }
    if (data.containsKey('cancelled')) {
      context.handle(
        _cancelledMeta,
        cancelled.isAcceptableOrUnknown(data['cancelled']!, _cancelledMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlastJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlastJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      sent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent'],
      )!,
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed'],
      )!,
      cancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cancelled'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BlastJobsTable createAlias(String alias) {
    return $BlastJobsTable(attachedDatabase, alias);
  }
}

class BlastJob extends DataClass implements Insertable<BlastJob> {
  final String id;
  final String body;
  final String priority;
  final int total;
  final int sent;
  final int failed;
  final bool cancelled;
  final String status;
  final DateTime createdAt;
  const BlastJob({
    required this.id,
    required this.body,
    required this.priority,
    required this.total,
    required this.sent,
    required this.failed,
    required this.cancelled,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['body'] = Variable<String>(body);
    map['priority'] = Variable<String>(priority);
    map['total'] = Variable<int>(total);
    map['sent'] = Variable<int>(sent);
    map['failed'] = Variable<int>(failed);
    map['cancelled'] = Variable<bool>(cancelled);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BlastJobsCompanion toCompanion(bool nullToAbsent) {
    return BlastJobsCompanion(
      id: Value(id),
      body: Value(body),
      priority: Value(priority),
      total: Value(total),
      sent: Value(sent),
      failed: Value(failed),
      cancelled: Value(cancelled),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory BlastJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlastJob(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      priority: serializer.fromJson<String>(json['priority']),
      total: serializer.fromJson<int>(json['total']),
      sent: serializer.fromJson<int>(json['sent']),
      failed: serializer.fromJson<int>(json['failed']),
      cancelled: serializer.fromJson<bool>(json['cancelled']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'body': serializer.toJson<String>(body),
      'priority': serializer.toJson<String>(priority),
      'total': serializer.toJson<int>(total),
      'sent': serializer.toJson<int>(sent),
      'failed': serializer.toJson<int>(failed),
      'cancelled': serializer.toJson<bool>(cancelled),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BlastJob copyWith({
    String? id,
    String? body,
    String? priority,
    int? total,
    int? sent,
    int? failed,
    bool? cancelled,
    String? status,
    DateTime? createdAt,
  }) => BlastJob(
    id: id ?? this.id,
    body: body ?? this.body,
    priority: priority ?? this.priority,
    total: total ?? this.total,
    sent: sent ?? this.sent,
    failed: failed ?? this.failed,
    cancelled: cancelled ?? this.cancelled,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  BlastJob copyWithCompanion(BlastJobsCompanion data) {
    return BlastJob(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      priority: data.priority.present ? data.priority.value : this.priority,
      total: data.total.present ? data.total.value : this.total,
      sent: data.sent.present ? data.sent.value : this.sent,
      failed: data.failed.present ? data.failed.value : this.failed,
      cancelled: data.cancelled.present ? data.cancelled.value : this.cancelled,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlastJob(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('priority: $priority, ')
          ..write('total: $total, ')
          ..write('sent: $sent, ')
          ..write('failed: $failed, ')
          ..write('cancelled: $cancelled, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    body,
    priority,
    total,
    sent,
    failed,
    cancelled,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlastJob &&
          other.id == this.id &&
          other.body == this.body &&
          other.priority == this.priority &&
          other.total == this.total &&
          other.sent == this.sent &&
          other.failed == this.failed &&
          other.cancelled == this.cancelled &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class BlastJobsCompanion extends UpdateCompanion<BlastJob> {
  final Value<String> id;
  final Value<String> body;
  final Value<String> priority;
  final Value<int> total;
  final Value<int> sent;
  final Value<int> failed;
  final Value<bool> cancelled;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BlastJobsCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.priority = const Value.absent(),
    this.total = const Value.absent(),
    this.sent = const Value.absent(),
    this.failed = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlastJobsCompanion.insert({
    required String id,
    required String body,
    this.priority = const Value.absent(),
    this.total = const Value.absent(),
    this.sent = const Value.absent(),
    this.failed = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body);
  static Insertable<BlastJob> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<String>? priority,
    Expression<int>? total,
    Expression<int>? sent,
    Expression<int>? failed,
    Expression<bool>? cancelled,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (priority != null) 'priority': priority,
      if (total != null) 'total': total,
      if (sent != null) 'sent': sent,
      if (failed != null) 'failed': failed,
      if (cancelled != null) 'cancelled': cancelled,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlastJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<String>? priority,
    Value<int>? total,
    Value<int>? sent,
    Value<int>? failed,
    Value<bool>? cancelled,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BlastJobsCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      priority: priority ?? this.priority,
      total: total ?? this.total,
      sent: sent ?? this.sent,
      failed: failed ?? this.failed,
      cancelled: cancelled ?? this.cancelled,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (sent.present) {
      map['sent'] = Variable<int>(sent.value);
    }
    if (failed.present) {
      map['failed'] = Variable<int>(failed.value);
    }
    if (cancelled.present) {
      map['cancelled'] = Variable<bool>(cancelled.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlastJobsCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('priority: $priority, ')
          ..write('total: $total, ')
          ..write('sent: $sent, ')
          ..write('failed: $failed, ')
          ..write('cancelled: $cancelled, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlastRecipientsTable extends BlastRecipients
    with TableInfo<$BlastRecipientsTable, BlastRecipient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlastRecipientsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _blastIdMeta = const VerificationMeta(
    'blastId',
  );
  @override
  late final GeneratedColumn<String> blastId = GeneratedColumn<String>(
    'blast_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
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
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, blastId, address, status, error];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blast_recipients';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlastRecipient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('blast_id')) {
      context.handle(
        _blastIdMeta,
        blastId.isAcceptableOrUnknown(data['blast_id']!, _blastIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blastIdMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlastRecipient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlastRecipient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      blastId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blast_id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $BlastRecipientsTable createAlias(String alias) {
    return $BlastRecipientsTable(attachedDatabase, alias);
  }
}

class BlastRecipient extends DataClass implements Insertable<BlastRecipient> {
  final int id;
  final String blastId;
  final String address;
  final String status;
  final String? error;
  const BlastRecipient({
    required this.id,
    required this.blastId,
    required this.address,
    required this.status,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['blast_id'] = Variable<String>(blastId);
    map['address'] = Variable<String>(address);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  BlastRecipientsCompanion toCompanion(bool nullToAbsent) {
    return BlastRecipientsCompanion(
      id: Value(id),
      blastId: Value(blastId),
      address: Value(address),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory BlastRecipient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlastRecipient(
      id: serializer.fromJson<int>(json['id']),
      blastId: serializer.fromJson<String>(json['blastId']),
      address: serializer.fromJson<String>(json['address']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'blastId': serializer.toJson<String>(blastId),
      'address': serializer.toJson<String>(address),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
    };
  }

  BlastRecipient copyWith({
    int? id,
    String? blastId,
    String? address,
    String? status,
    Value<String?> error = const Value.absent(),
  }) => BlastRecipient(
    id: id ?? this.id,
    blastId: blastId ?? this.blastId,
    address: address ?? this.address,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
  );
  BlastRecipient copyWithCompanion(BlastRecipientsCompanion data) {
    return BlastRecipient(
      id: data.id.present ? data.id.value : this.id,
      blastId: data.blastId.present ? data.blastId.value : this.blastId,
      address: data.address.present ? data.address.value : this.address,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlastRecipient(')
          ..write('id: $id, ')
          ..write('blastId: $blastId, ')
          ..write('address: $address, ')
          ..write('status: $status, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, blastId, address, status, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlastRecipient &&
          other.id == this.id &&
          other.blastId == this.blastId &&
          other.address == this.address &&
          other.status == this.status &&
          other.error == this.error);
}

class BlastRecipientsCompanion extends UpdateCompanion<BlastRecipient> {
  final Value<int> id;
  final Value<String> blastId;
  final Value<String> address;
  final Value<String> status;
  final Value<String?> error;
  const BlastRecipientsCompanion({
    this.id = const Value.absent(),
    this.blastId = const Value.absent(),
    this.address = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
  });
  BlastRecipientsCompanion.insert({
    this.id = const Value.absent(),
    required String blastId,
    required String address,
    required String status,
    this.error = const Value.absent(),
  }) : blastId = Value(blastId),
       address = Value(address),
       status = Value(status);
  static Insertable<BlastRecipient> custom({
    Expression<int>? id,
    Expression<String>? blastId,
    Expression<String>? address,
    Expression<String>? status,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (blastId != null) 'blast_id': blastId,
      if (address != null) 'address': address,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
    });
  }

  BlastRecipientsCompanion copyWith({
    Value<int>? id,
    Value<String>? blastId,
    Value<String>? address,
    Value<String>? status,
    Value<String?>? error,
  }) {
    return BlastRecipientsCompanion(
      id: id ?? this.id,
      blastId: blastId ?? this.blastId,
      address: address ?? this.address,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (blastId.present) {
      map['blast_id'] = Variable<String>(blastId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlastRecipientsCompanion(')
          ..write('id: $id, ')
          ..write('blastId: $blastId, ')
          ..write('address: $address, ')
          ..write('status: $status, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SmsTemplatesTable smsTemplates = $SmsTemplatesTable(this);
  late final $BlastJobsTable blastJobs = $BlastJobsTable(this);
  late final $BlastRecipientsTable blastRecipients = $BlastRecipientsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    smsTemplates,
    blastJobs,
    blastRecipients,
  ];
}

typedef $$SmsTemplatesTableCreateCompanionBuilder =
    SmsTemplatesCompanion Function({
      Value<int> id,
      required String title,
      required String body,
      Value<DateTime> createdAt,
    });
typedef $$SmsTemplatesTableUpdateCompanionBuilder =
    SmsTemplatesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> body,
      Value<DateTime> createdAt,
    });

class $$SmsTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $SmsTemplatesTable> {
  $$SmsTemplatesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SmsTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SmsTemplatesTable> {
  $$SmsTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SmsTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SmsTemplatesTable> {
  $$SmsTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SmsTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SmsTemplatesTable,
          SmsTemplate,
          $$SmsTemplatesTableFilterComposer,
          $$SmsTemplatesTableOrderingComposer,
          $$SmsTemplatesTableAnnotationComposer,
          $$SmsTemplatesTableCreateCompanionBuilder,
          $$SmsTemplatesTableUpdateCompanionBuilder,
          (
            SmsTemplate,
            BaseReferences<_$AppDatabase, $SmsTemplatesTable, SmsTemplate>,
          ),
          SmsTemplate,
          PrefetchHooks Function()
        > {
  $$SmsTemplatesTableTableManager(_$AppDatabase db, $SmsTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmsTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmsTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmsTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SmsTemplatesCompanion(
                id: id,
                title: title,
                body: body,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String body,
                Value<DateTime> createdAt = const Value.absent(),
              }) => SmsTemplatesCompanion.insert(
                id: id,
                title: title,
                body: body,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SmsTemplatesTable, SmsTemplate>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SmsTemplatesTable,
                    SmsTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SmsTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SmsTemplatesTable,
      SmsTemplate,
      $$SmsTemplatesTableFilterComposer,
      $$SmsTemplatesTableOrderingComposer,
      $$SmsTemplatesTableAnnotationComposer,
      $$SmsTemplatesTableCreateCompanionBuilder,
      $$SmsTemplatesTableUpdateCompanionBuilder,
      (
        SmsTemplate,
        BaseReferences<_$AppDatabase, $SmsTemplatesTable, SmsTemplate>,
      ),
      SmsTemplate,
      PrefetchHooks Function()
    >;
typedef $$BlastJobsTableCreateCompanionBuilder =
    BlastJobsCompanion Function({
      required String id,
      required String body,
      Value<String> priority,
      Value<int> total,
      Value<int> sent,
      Value<int> failed,
      Value<bool> cancelled,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BlastJobsTableUpdateCompanionBuilder =
    BlastJobsCompanion Function({
      Value<String> id,
      Value<String> body,
      Value<String> priority,
      Value<int> total,
      Value<int> sent,
      Value<int> failed,
      Value<bool> cancelled,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BlastJobsTableFilterComposer
    extends Composer<_$AppDatabase, $BlastJobsTable> {
  $$BlastJobsTableFilterComposer({
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sent => $composableBuilder(
    column: $table.sent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlastJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlastJobsTable> {
  $$BlastJobsTableOrderingComposer({
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sent => $composableBuilder(
    column: $table.sent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlastJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlastJobsTable> {
  $$BlastJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get sent =>
      $composableBuilder(column: $table.sent, builder: (column) => column);

  GeneratedColumn<int> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);

  GeneratedColumn<bool> get cancelled =>
      $composableBuilder(column: $table.cancelled, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BlastJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlastJobsTable,
          BlastJob,
          $$BlastJobsTableFilterComposer,
          $$BlastJobsTableOrderingComposer,
          $$BlastJobsTableAnnotationComposer,
          $$BlastJobsTableCreateCompanionBuilder,
          $$BlastJobsTableUpdateCompanionBuilder,
          (BlastJob, BaseReferences<_$AppDatabase, $BlastJobsTable, BlastJob>),
          BlastJob,
          PrefetchHooks Function()
        > {
  $$BlastJobsTableTableManager(_$AppDatabase db, $BlastJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlastJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlastJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlastJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> sent = const Value.absent(),
                Value<int> failed = const Value.absent(),
                Value<bool> cancelled = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlastJobsCompanion(
                id: id,
                body: body,
                priority: priority,
                total: total,
                sent: sent,
                failed: failed,
                cancelled: cancelled,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String body,
                Value<String> priority = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> sent = const Value.absent(),
                Value<int> failed = const Value.absent(),
                Value<bool> cancelled = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlastJobsCompanion.insert(
                id: id,
                body: body,
                priority: priority,
                total: total,
                sent: sent,
                failed: failed,
                cancelled: cancelled,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlastJobsTable, BlastJob>(table),
                  BaseReferences<_$AppDatabase, $BlastJobsTable, BlastJob>(
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

typedef $$BlastJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlastJobsTable,
      BlastJob,
      $$BlastJobsTableFilterComposer,
      $$BlastJobsTableOrderingComposer,
      $$BlastJobsTableAnnotationComposer,
      $$BlastJobsTableCreateCompanionBuilder,
      $$BlastJobsTableUpdateCompanionBuilder,
      (BlastJob, BaseReferences<_$AppDatabase, $BlastJobsTable, BlastJob>),
      BlastJob,
      PrefetchHooks Function()
    >;
typedef $$BlastRecipientsTableCreateCompanionBuilder =
    BlastRecipientsCompanion Function({
      Value<int> id,
      required String blastId,
      required String address,
      required String status,
      Value<String?> error,
    });
typedef $$BlastRecipientsTableUpdateCompanionBuilder =
    BlastRecipientsCompanion Function({
      Value<int> id,
      Value<String> blastId,
      Value<String> address,
      Value<String> status,
      Value<String?> error,
    });

class $$BlastRecipientsTableFilterComposer
    extends Composer<_$AppDatabase, $BlastRecipientsTable> {
  $$BlastRecipientsTableFilterComposer({
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

  ColumnFilters<String> get blastId => $composableBuilder(
    column: $table.blastId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlastRecipientsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlastRecipientsTable> {
  $$BlastRecipientsTableOrderingComposer({
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

  ColumnOrderings<String> get blastId => $composableBuilder(
    column: $table.blastId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlastRecipientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlastRecipientsTable> {
  $$BlastRecipientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get blastId =>
      $composableBuilder(column: $table.blastId, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$BlastRecipientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlastRecipientsTable,
          BlastRecipient,
          $$BlastRecipientsTableFilterComposer,
          $$BlastRecipientsTableOrderingComposer,
          $$BlastRecipientsTableAnnotationComposer,
          $$BlastRecipientsTableCreateCompanionBuilder,
          $$BlastRecipientsTableUpdateCompanionBuilder,
          (
            BlastRecipient,
            BaseReferences<
              _$AppDatabase,
              $BlastRecipientsTable,
              BlastRecipient
            >,
          ),
          BlastRecipient,
          PrefetchHooks Function()
        > {
  $$BlastRecipientsTableTableManager(
    _$AppDatabase db,
    $BlastRecipientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlastRecipientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlastRecipientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlastRecipientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> blastId = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => BlastRecipientsCompanion(
                id: id,
                blastId: blastId,
                address: address,
                status: status,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String blastId,
                required String address,
                required String status,
                Value<String?> error = const Value.absent(),
              }) => BlastRecipientsCompanion.insert(
                id: id,
                blastId: blastId,
                address: address,
                status: status,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlastRecipientsTable, BlastRecipient>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BlastRecipientsTable,
                    BlastRecipient
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlastRecipientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlastRecipientsTable,
      BlastRecipient,
      $$BlastRecipientsTableFilterComposer,
      $$BlastRecipientsTableOrderingComposer,
      $$BlastRecipientsTableAnnotationComposer,
      $$BlastRecipientsTableCreateCompanionBuilder,
      $$BlastRecipientsTableUpdateCompanionBuilder,
      (
        BlastRecipient,
        BaseReferences<_$AppDatabase, $BlastRecipientsTable, BlastRecipient>,
      ),
      BlastRecipient,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SmsTemplatesTableTableManager get smsTemplates =>
      $$SmsTemplatesTableTableManager(_db, _db.smsTemplates);
  $$BlastJobsTableTableManager get blastJobs =>
      $$BlastJobsTableTableManager(_db, _db.blastJobs);
  $$BlastRecipientsTableTableManager get blastRecipients =>
      $$BlastRecipientsTableTableManager(_db, _db.blastRecipients);
}
