import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/app_database.dart';
import '../../database/db.dart';

/// Build and share a CSV of blast history (one row per recipient).
class BlastHistoryExporter {
  BlastHistoryExporter._();

  static String _csvEscape(String? raw) {
    final s = raw ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _iso(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static Future<String> buildCsv(List<BlastJob> jobs) async {
    final buf = StringBuffer();
    buf.writeln(
      'blast_id,date,priority,blast_status,sent,failed,total,body,recipient,recipient_status,error',
    );
    for (final job in jobs) {
      final rows = await appDatabase.recipientsFor(job.id);
      if (rows.isEmpty) {
        buf.writeln(
          [
            _csvEscape(job.id),
            _csvEscape(_iso(job.createdAt)),
            _csvEscape(job.priority),
            _csvEscape(job.status),
            job.sent,
            job.failed,
            job.total,
            _csvEscape(job.body),
            '',
            '',
            '',
          ].join(','),
        );
        continue;
      }
      for (final r in rows) {
        buf.writeln(
          [
            _csvEscape(job.id),
            _csvEscape(_iso(job.createdAt)),
            _csvEscape(job.priority),
            _csvEscape(job.status),
            job.sent,
            job.failed,
            job.total,
            _csvEscape(job.body),
            _csvEscape(r.address),
            _csvEscape(r.status),
            _csvEscape(r.error),
          ].join(','),
        );
      }
    }
    return buf.toString();
  }

  static Future<void> share({
    required List<BlastJob> jobs,
    required String label,
  }) async {
    final csv = await buildCsv(jobs);
    final dir = await getTemporaryDirectory();
    final safe = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final name = 'pyx_blast_${safe.isEmpty ? 'export' : safe}.csv';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: name)],
        subject: 'PYX Food Products blast history — $label',
        text: 'Blast history export ($label) from PYX Food Products.',
      ),
    );
  }
}
