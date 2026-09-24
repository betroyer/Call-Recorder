import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';
import '../../database/app_database.dart';
import '../../database/db.dart';
import 'sms_permission_help.dart';

/// Multi-recipient SMS blast with progress, contacts, templates, history, schedule.
class SmsBlastScreen extends StatefulWidget {
  const SmsBlastScreen({super.key});

  @override
  State<SmsBlastScreen> createState() => _SmsBlastScreenState();
}

class _SmsBlastScreenState extends State<SmsBlastScreen> {
  final _numbers = TextEditingController();
  final _message = TextEditingController();
  List<Map<String, dynamic>> _sims = const [];
  List<SmsTemplate> _templates = const [];
  List<BlastJob> _history = const [];
  int _subscriptionId = -1;
  String _priority = 'Low';
  DateTime? _scheduledAt;
  bool _sending = false;
  bool _smsSend = false;
  bool _isDefaultSms = false;

  int _progressIndex = 0;
  int _progressTotal = 0;
  int _progressSent = 0;
  int _progressFailed = 0;
  String? _progressAddress;
  List<Map<String, dynamic>> _lastResults = const [];
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _message.addListener(() => setState(() {}));
    _numbers.addListener(() => setState(() {}));
    CallBridge.listen();
    _eventsSub = CallBridge.events.listen((e) {
      if (e['type']?.toString() != 'onBlastProgress') return;
      if (!mounted) return;
      setState(() {
        _progressIndex = (e['index'] as num?)?.toInt() ?? _progressIndex;
        _progressTotal = (e['total'] as num?)?.toInt() ?? _progressTotal;
        _progressSent = (e['sent'] as num?)?.toInt() ?? _progressSent;
        _progressFailed = (e['failed'] as num?)?.toInt() ?? _progressFailed;
        _progressAddress = e['address']?.toString();
        if (e['done'] == true) {
          _sending = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _numbers.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final perms = await CallBridge.checkPermissions();
    _smsSend = perms['smsSend'] == true;
    _isDefaultSms = perms['defaultSms'] == true;
    try {
      _sims = await CallBridge.listSims();
      _templates = await appDatabase.allTemplates();
      _history = await appDatabase.recentBlasts();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _request() async {
    await CallBridge.requestPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _bootstrap();
  }

  List<String> _parseNumbers(String raw) {
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  ({int chars, int pages}) _smsMeta(String text) {
    final isGsm = text.codeUnits.every((c) => c <= 127);
    final limit = isGsm ? 160 : 70;
    final multi = isGsm ? 153 : 67;
    final len = text.length;
    if (len == 0) return (chars: 0, pages: 1);
    if (len <= limit) return (chars: len, pages: 1);
    return (chars: len, pages: ((len + multi - 1) ~/ multi));
  }

  Future<void> _pickContacts() async {
    final perms = await CallBridge.checkPermissions();
    if (perms['contacts'] != true) {
      await CallBridge.requestPermissions();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    final contacts = await CallBridge.listContacts();
    if (!mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts with numbers (grant Contacts permission)')),
      );
      return;
    }
    final selected = <String>{};
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Pick contacts'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    final number = c['number']?.toString() ?? '';
                    final name = c['name']?.toString() ?? '';
                    final checked = selected.contains(number);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(name.isEmpty ? number : name),
                      subtitle: Text(number),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(number);
                          } else {
                            selected.remove(number);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final existing = _parseNumbers(_numbers.text).toSet();
                    existing.addAll(selected);
                    _numbers.text = existing.join('\n');
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: Text('Add (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveTemplate() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    final titleCtrl = TextEditingController(text: body.length > 24 ? '${body.substring(0, 24)}…' : body);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save template'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await appDatabase.addTemplate(titleCtrl.text.trim().isEmpty ? 'Template' : titleCtrl.text.trim(), body);
      await _bootstrap();
    }
    titleCtrl.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _scheduledAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now.add(const Duration(minutes: 5))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<bool> _confirmRateLimit(int count) async {
    if (count < 20) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Large SMS blast'),
        content: Text(
          'You are about to send to $count numbers.\n\n'
          'Carriers may rate-limit or block bulk SMS. '
          'Messages are paced (~400ms apart). Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send anyway')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _send() async {
    final recipients = _parseNumbers(_numbers.text);
    final body = _message.text.trim();
    if (recipients.isEmpty || body.isEmpty || _sending) return;
    if (!await _confirmRateLimit(recipients.length)) return;

    final branded = AppBrand.brandMessage(body);
    final allSims = _subscriptionId < 0;

    if (_scheduledAt != null && _scheduledAt!.isAfter(DateTime.now().add(const Duration(seconds: 5)))) {
      final result = await CallBridge.scheduleSmsBlast(
        addresses: recipients,
        body: branded,
        triggerAtMs: _scheduledAt!.millisecondsSinceEpoch,
        subscriptionId: allSims ? -1 : _subscriptionId,
        allSims: allSims,
        priority: _priority,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['ok'] == true
                ? 'Scheduled blast for ${_scheduledAt!.toLocal()} (${recipients.length} numbers)'
                : 'Schedule failed: ${result['error']}',
          ),
        ),
      );
      return;
    }

    await _doSend(recipients, branded, allSims);
  }

  Future<void> _doSend(List<String> recipients, String body, bool allSims) async {
    final blastId = const Uuid().v4();
    setState(() {
      _sending = true;
      _progressIndex = 0;
      _progressTotal = recipients.length;
      _progressSent = 0;
      _progressFailed = 0;
      _progressAddress = null;
      _lastResults = const [];
    });
    try {
      final result = await CallBridge.sendSmsBlast(
        addresses: recipients,
        body: body,
        subscriptionId: allSims ? -1 : _subscriptionId,
        allSims: allSims,
        blastId: blastId,
      );
      final results = (result['results'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      await appDatabase.saveBlastResult(
        id: blastId,
        body: body,
        priority: _priority,
        total: (result['total'] as num?)?.toInt() ?? recipients.length,
        sent: (result['sent'] as num?)?.toInt() ?? 0,
        failed: (result['failed'] as num?)?.toInt() ?? 0,
        cancelled: result['cancelled'] == true,
        results: results,
      );
      if (!mounted) return;
      setState(() {
        _lastResults = results;
        _sending = false;
      });
      await _bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blast ${result['cancelled'] == true ? 'cancelled' : 'done'} · '
            'sent ${result['sent']} · failed ${result['failed']}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blast failed: $e')),
        );
      }
    }
  }

  Future<void> _showHistoryDetail(BlastJob job) async {
    final rows = await appDatabase.recipientsFor(job.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.7,
            child: Column(
              children: [
                ListTile(
                  title: Text('Blast · ${job.sent}/${job.total} sent'),
                  subtitle: Text(job.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return ListTile(
                        dense: true,
                        title: Text(r.address),
                        trailing: Text(r.status),
                        subtitle: r.error == null ? null : Text(r.error!),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _smsMeta(_message.text);
    final count = _parseNumbers(_numbers.text).length;
    final scheduleLabel = _scheduledAt == null
        ? 'Send now'
        : '${_scheduledAt!.month}/${_scheduledAt!.day} '
            '${_scheduledAt!.hour.toString().padLeft(2, '0')}:'
            '${_scheduledAt!.minute.toString().padLeft(2, '0')}';

    final simItems = _sims.isEmpty
        ? [const DropdownMenuItem(value: -1, child: Text('Auto — try SIM with load'))]
        : _sims
            .map(
              (s) => DropdownMenuItem(
                value: (s['id'] as num?)?.toInt() ?? -1,
                child: Text('${s['label']}'),
              ),
            )
            .toList();

    final numbersPane = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Recipients ($count)', style: Theme.of(context).textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _pickContacts,
              icon: const Icon(Icons.contacts, size: 18),
              label: const Text('Contacts'),
            ),
          ],
        ),
        Expanded(
          child: TextField(
            controller: _numbers,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Mobile numbers (ex. 09178943492)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );

    final messagePane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_smsSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SmsPermissionHelp(onRequest: _request),
          ),
        if (!_isDefaultSms)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () async {
                await CallBridge.requestDefaultSmsRole();
                await _bootstrap();
              },
              child: const Text('Set as default SMS app (better inbox/sent sync)'),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _message,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'SMS message',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${meta.chars} character  ${meta.pages} SMS page · $count recipient(s)'),
        if (_templates.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in _templates)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(t.title),
                      onPressed: () => setState(() => _message.text = t.body),
                      onDeleted: () async {
                        await appDatabase.deleteTemplate(t.id);
                        await _bootstrap();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(onPressed: _saveTemplate, child: const Text('Save template')),
            TextButton(
              onPressed: () {
                final recipients = _parseNumbers(_numbers.text);
                CallBridge.openMmsComposer(addresses: recipients, body: _message.text);
              },
              child: const Text('Open MMS'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _priority,
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'Low'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Send via',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: simItems.any((e) => e.value == _subscriptionId)
                        ? _subscriptionId
                        : -1,
                    items: simItems,
                    onChanged: (v) => setState(() => _subscriptionId = v ?? -1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _pickSchedule,
                onLongPress: () => setState(() => _scheduledAt = null),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Schedule later',
                    labelStyle: TextStyle(color: Color(0xFF2E7D32)),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  ),
                  child: Text(scheduleLabel),
                ),
              ),
            ),
          ],
        ),
        if (_sending) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progressTotal == 0 ? null : (_progressIndex + 1) / _progressTotal,
          ),
          const SizedBox(height: 4),
          Text(
            'Sending ${_progressIndex + 1}/$_progressTotal'
            '${_progressAddress != null ? ' · $_progressAddress' : ''}'
            ' · sent $_progressSent · failed $_progressFailed',
          ),
          TextButton(
            onPressed: () => CallBridge.cancelSmsBlast(),
            child: const Text('Cancel blast'),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 140,
            height: 44,
            child: FilledButton(
              onPressed: !_smsSend || _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: const RoundedRectangleBorder(),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SEND'),
            ),
          ),
        ),
        if (_lastResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Last blast status', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(
            height: 120,
            child: ListView.builder(
              itemCount: _lastResults.length,
              itemBuilder: (_, i) {
                final r = _lastResults[i];
                return ListTile(
                  dense: true,
                  title: Text('${r['address']}'),
                  trailing: Text('${r['status'] ?? (r['ok'] == true ? 'sent' : 'failed')}'),
                );
              },
            ),
          ),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('History', style: Theme.of(context).textTheme.titleSmall),
          ..._history.take(8).map(
                (h) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${h.sent}/${h.total} · ${h.priority}'),
                  subtitle: Text(h.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _showHistoryDetail(h),
                ),
              ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: numbersPane),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: messagePane),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: constraints.maxHeight * 0.28, child: numbersPane),
              const SizedBox(height: 8),
              Expanded(child: messagePane),
            ],
          );
        },
      ),
    );
  }
}
