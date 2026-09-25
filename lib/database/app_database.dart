import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../contacts/phone_match.dart';

part 'app_database.g.dart';

class SmsTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BlastJobs extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  TextColumn get priority => text().withDefault(const Constant('Low'))();
  /// 0 = normal blast; 1–3 = undelivered-order follow-up attempt.
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get sent => integer().withDefault(const Constant(0))();
  IntColumn get failed => integer().withDefault(const Constant(0))();
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('done'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BlastRecipients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get blastId => text()();
  TextColumn get address => text()();
  TextColumn get status => text()(); // sent | failed | cancelled
  TextColumn get error => text().nullable()();
}

@DriftDatabase(tables: [SmsTemplates, BlastJobs, BlastRecipients])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(blastJobs, blastJobs.attempt);
          }
        },
      );

  Future<List<SmsTemplate>> allTemplates() =>
      (select(smsTemplates)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<int> addTemplate(String title, String body) {
    return into(smsTemplates).insert(
      SmsTemplatesCompanion.insert(title: title, body: body),
    );
  }

  Future<int> deleteTemplate(int id) =>
      (delete(smsTemplates)..where((t) => t.id.equals(id))).go();

  Future<void> saveBlastResult({
    required String id,
    required String body,
    required String priority,
    int attempt = 0,
    required int total,
    required int sent,
    required int failed,
    required bool cancelled,
    required List<Map<String, dynamic>> results,
  }) async {
    await into(blastJobs).insertOnConflictUpdate(
      BlastJobsCompanion.insert(
        id: id,
        body: body,
        priority: Value(priority),
        attempt: Value(attempt),
        total: Value(total),
        sent: Value(sent),
        failed: Value(failed),
        cancelled: Value(cancelled),
        status: Value(cancelled ? 'cancelled' : 'done'),
      ),
    );
    await (delete(blastRecipients)..where((t) => t.blastId.equals(id))).go();
    for (final r in results) {
      await into(blastRecipients).insert(
        BlastRecipientsCompanion.insert(
          blastId: id,
          address: '${r['address'] ?? ''}',
          status: '${r['status'] ?? (r['ok'] == true ? 'sent' : 'failed')}',
          error: Value(r['error']?.toString()),
        ),
      );
    }
  }

  Future<List<BlastJob>> recentBlasts({int limit = 50}) =>
      (select(blastJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  /// [from] inclusive, [to] exclusive. Nulls mean no bound on that side.
  Future<List<BlastJob>> blastsInRange({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) {
    final q = select(blastJobs)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    if (from != null && to != null) {
      q.where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(from) &
            t.createdAt.isSmallerThanValue(to),
      );
    } else if (from != null) {
      q.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    } else if (to != null) {
      q.where((t) => t.createdAt.isSmallerThanValue(to));
    }
    return q.get();
  }

  Future<List<BlastRecipient>> recipientsFor(String blastId) =>
      (select(blastRecipients)..where((t) => t.blastId.equals(blastId))).get();

  Future<List<String>> failedAddressesForBlast(String blastId) async {
    final rows = await (select(blastRecipients)
          ..where(
            (t) =>
                t.blastId.equals(blastId) &
                (t.status.equals('failed') | t.status.equals('cancelled')),
          ))
        .get();
    return PhoneMatch.uniqueNormalized(rows.map((r) => r.address));
  }

  /// Highest successful follow-up attempt (1–3) per match key.
  Future<Map<String, int>> maxSentAttemptByKey() async {
    final jobs = await (select(blastJobs)
          ..where((t) => t.attempt.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final map = <String, int>{};
    for (final job in jobs) {
      final rows = await recipientsFor(job.id);
      for (final r in rows) {
        if (r.status != 'sent') continue;
        final key = PhoneMatch.matchKey(r.address);
        if (key.isEmpty) continue;
        final prev = map[key] ?? 0;
        if (job.attempt > prev) map[key] = job.attempt;
      }
    }
    return map;
  }

  Future<BlastJob?> latestBlastWithAttempt(int attempt) async {
    return (select(blastJobs)
          ..where((t) => t.attempt.equals(attempt))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<BlastJob?> latestBlast() async {
    return (select(blastJobs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'callvault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
