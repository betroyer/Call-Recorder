import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';

/// Multi-recipient SMS blast UI (numbers left, message + options right).
class SmsBlastScreen extends StatefulWidget {
  const SmsBlastScreen({super.key});

  @override
  State<SmsBlastScreen> createState() => _SmsBlastScreenState();
}

class _SmsBlastScreenState extends State<SmsBlastScreen> {
  final _numbers = TextEditingController();
  final _message = TextEditingController();
  List<Map<String, dynamic>> _sims = const [];
  int _subscriptionId = -1;
  String _priority = 'Low';
  DateTime? _scheduledAt;
  bool _sending = false;
  bool _smsSend = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _message.addListener(() => setState(() {}));
    _numbers.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _numbers.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final perms = await CallBridge.checkPermissions();
    _smsSend = perms['smsSend'] == true;
    try {
      _sims = await CallBridge.listSims();
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

  Future<void> _send() async {
    final recipients = _parseNumbers(_numbers.text);
    final body = _message.text.trim();
    if (recipients.isEmpty || body.isEmpty || _sending) return;

    if (_scheduledAt != null && _scheduledAt!.isAfter(DateTime.now())) {
      final delay = _scheduledAt!.difference(DateTime.now());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled in ${delay.inMinutes} min for ${recipients.length} number(s). '
            'Keep the app open (prototype scheduler).',
          ),
        ),
      );
      setState(() => _sending = true);
      Future<void>.delayed(delay, () async {
        await _doSend(recipients, body);
      });
      return;
    }

    await _doSend(recipients, body);
  }

  Future<void> _doSend(List<String> recipients, String body) async {
    if (mounted) setState(() => _sending = true);
    try {
      final allSims = _subscriptionId < 0;
      final result = await CallBridge.sendSmsBlast(
        addresses: recipients,
        body: body,
        subscriptionId: allSims ? -1 : _subscriptionId,
        allSims: allSims,
      );
      if (!mounted) return;
      final sent = result['sent'];
      final failed = result['failed'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blast done · sent $sent · failed $failed'
            '${_priority.isNotEmpty ? ' · priority $_priority' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blast failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        ? [
            const DropdownMenuItem(value: -1, child: Text('ALL SIMs')),
          ]
        : _sims
            .map(
              (s) => DropdownMenuItem(
                value: (s['id'] as num?)?.toInt() ?? -1,
                child: Text('${s['label']}'),
              ),
            )
            .toList();

    final numbersPane = TextField(
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
    );

    final messagePane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_smsSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _request,
              child: const Text('Grant SMS permissions'),
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
        const SizedBox(height: 12),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SEND'),
            ),
          ),
        ),
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
              SizedBox(height: constraints.maxHeight * 0.32, child: numbersPane),
              const SizedBox(height: 12),
              Expanded(child: messagePane),
            ],
          );
        },
      ),
    );
  }
}
