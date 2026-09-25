import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';
import '../../contacts/phone_match.dart';
import '../../database/app_database.dart';
import '../../database/db.dart';
import '../../widgets/app_ui.dart';
import 'blast_history_exporter.dart';
import 'quick_templates_bar.dart';
import 'slash_quick_reply.dart';
import 'sms_permission_help.dart';

/// Multi-recipient SMS blast with progress, contacts, templates, history, schedule.
class SmsBlastScreen extends StatefulWidget {
  const SmsBlastScreen({super.key});

  @override
  State<SmsBlastScreen> createState() => _SmsBlastScreenState();
}

class _SmsBlastScreenState extends State<SmsBlastScreen> with WidgetsBindingObserver {
  final _numbers = TextEditingController();
  final _message = TextEditingController();
  List<Map<String, dynamic>> _sims = const [];
  List<BlastJob> _history = const [];
  int _subscriptionId = -1;
  String _priority = 'Low';
  /// 0 = normal; 1–3 = undelivered-order follow-up attempt.
  int _attempt = 0;
  DateTime? _scheduledAt;
  bool _sending = false;
  bool _smsSend = false;
  bool _isDefaultSms = false;
  bool _aggressiveOem = false;
  bool _ignoringBattery = true;
  String _deviceLabel = '';
  List<String> _oemTips = const [];

  int _progressIndex = 0;
  int _progressTotal = 0;
  int _progressSent = 0;
  int _progressFailed = 0;
  String? _progressAddress;
  List<Map<String, dynamic>> _lastResults = const [];
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  /// History date filter: all | today | yesterday | week | month | day | custom month
  String _historyFilter = 'all';
  DateTime? _filterDay; // start of selected calendar day
  DateTime? _filterMonth; // first day of selected month
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      final hints = await CallBridge.deviceSmsHints();
      _aggressiveOem = hints['aggressiveOem'] == true;
      _ignoringBattery = hints['ignoringBatteryOptimizations'] == true;
      final brand = hints['brand']?.toString() ?? '';
      final model = hints['model']?.toString() ?? '';
      _deviceLabel = [brand, model].where((s) => s.trim().isNotEmpty).join(' ');
      _oemTips = (hints['tips'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [];
      await _loadHistory();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month);

  ({DateTime? from, DateTime? to}) _historyRange() {
    final now = DateTime.now();
    switch (_historyFilter) {
      case 'today':
        final from = _startOfDay(now);
        return (from: from, to: from.add(const Duration(days: 1)));
      case 'yesterday':
        final from = _startOfDay(now).subtract(const Duration(days: 1));
        return (from: from, to: from.add(const Duration(days: 1)));
      case 'week':
        final to = _startOfDay(now).add(const Duration(days: 1));
        return (from: to.subtract(const Duration(days: 7)), to: to);
      case 'month':
        final from = _startOfMonth(now);
        return (from: from, to: DateTime(from.year, from.month + 1));
      case 'day':
        if (_filterDay == null) return (from: null, to: null);
        final from = _startOfDay(_filterDay!);
        return (from: from, to: from.add(const Duration(days: 1)));
      case 'pickMonth':
        if (_filterMonth == null) return (from: null, to: null);
        final from = _startOfMonth(_filterMonth!);
        return (from: from, to: DateTime(from.year, from.month + 1));
      default:
        return (from: null, to: null);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final range = _historyRange();
      final list = await appDatabase.blastsInRange(
        from: range.from,
        to: range.to,
        limit: 200,
      );
      if (mounted) setState(() => _history = list);
    } catch (_) {
      if (mounted) setState(() => _history = const []);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _setHistoryFilter(String key) async {
    setState(() {
      _historyFilter = key;
      if (key != 'day') _filterDay = null;
      if (key != 'pickMonth') _filterMonth = null;
    });
    await _loadHistory();
  }

  Future<void> _pickHistoryDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDay ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Blasts on this day',
    );
    if (picked == null) return;
    setState(() {
      _historyFilter = 'day';
      _filterDay = picked;
      _filterMonth = null;
    });
    await _loadHistory();
  }

  Future<void> _pickHistoryMonth() async {
    final now = DateTime.now();
    // Month picker via date picker (day ignored; use first of month).
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterMonth ?? DateTime(now.year, now.month),
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Pick any day in the month',
    );
    if (picked == null) return;
    setState(() {
      _historyFilter = 'pickMonth';
      _filterMonth = DateTime(picked.year, picked.month);
      _filterDay = null;
    });
    await _loadHistory();
  }

  String _formatHistoryDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = _startOfDay(now);
    final day = _startOfDay(local);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Today · $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday · $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final datePart = local.year == now.year
        ? '${months[local.month - 1]} ${local.day}'
        : '${months[local.month - 1]} ${local.day}, ${local.year}';
    return '$datePart · $time';
  }

  String _filterLabel() {
    switch (_historyFilter) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'week':
        return 'Last 7 days';
      case 'month':
        return 'This month';
      case 'day':
        if (_filterDay == null) return 'Pick day';
        return _formatHistoryDate(_startOfDay(_filterDay!)).split(' · ').first;
      case 'pickMonth':
        if (_filterMonth == null) return 'Pick month';
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return '${months[_filterMonth!.month - 1]} ${_filterMonth!.year}';
      default:
        return 'All';
    }
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

  List<String> _uniqueRecipients() =>
      PhoneMatch.uniqueNormalized(_parseNumbers(_numbers.text));

  String _attemptLabel(int attempt) => switch (attempt) {
        1 => '1st attempt',
        2 => '2nd attempt',
        3 => '3rd attempt',
        _ => 'Normal blast',
      };

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

  Future<bool> _confirmRateLimit(int pasted, int unique) async {
    final dupes = pasted - unique;
    if (unique < 20 && dupes == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _attempt > 0
              ? 'Send ${_attemptLabel(_attempt)}?'
              : 'Confirm SMS blast',
        ),
        content: Text(
          'Pasted: $pasted number${pasted == 1 ? '' : 's'}\n'
          'Will send to: $unique unique'
          '${dupes > 0 ? ' ($dupes duplicate${dupes == 1 ? '' : 's'} skipped)' : ''}\n\n'
          '${_attempt > 0 ? 'Tagged as ${_attemptLabel(_attempt)} (undelivered-order follow-up).\n\n' : ''}'
          'No recipient limit — blasts are paced ~2s apart (slower after failures). '
          'Keep the app open. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _loadFailedFromBlast(BlastJob job) async {
    final failed = await appDatabase.failedAddressesForBlast(job.id);
    if (!mounted) return;
    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No failed/cancelled numbers in that blast')),
      );
      return;
    }
    setState(() {
      _numbers.text = failed.join('\n');
      if (job.attempt > 0) _attempt = job.attempt;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded ${failed.length} failed numbers')),
    );
  }

  Future<void> _loadFailedFromLast() async {
    final job = _attempt > 0
        ? await appDatabase.latestBlastWithAttempt(_attempt)
        : await appDatabase.latestBlast();
    if (job == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous blast found')),
      );
      return;
    }
    await _loadFailedFromBlast(job);
  }

  /// Drop numbers that already got this attempt (or higher) successfully.
  Future<void> _trimAlreadyAttempted() async {
    if (_attempt <= 0) return;
    final unique = _uniqueRecipients();
    if (unique.isEmpty) return;
    final maxByKey = await appDatabase.maxSentAttemptByKey();
    final kept = <String>[];
    var skipped = 0;
    for (final n in unique) {
      final key = PhoneMatch.matchKey(n);
      final done = maxByKey[key] ?? 0;
      if (done >= _attempt) {
        skipped++;
      } else {
        kept.add(n);
      }
    }
    if (!mounted) return;
    setState(() => _numbers.text = kept.join('\n'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped == 0
              ? 'None already completed ${_attemptLabel(_attempt)}'
              : 'Removed $skipped already on ${_attemptLabel(_attempt)}+ · ${kept.length} left',
        ),
      ),
    );
  }

  Future<void> _send() async {
    final pasted = _parseNumbers(_numbers.text);
    final recipients = PhoneMatch.uniqueNormalized(pasted);
    final body = _message.text.trim();
    if (recipients.isEmpty || body.isEmpty || _sending) return;

    // Re-check default SMS every send (OEMs can lag after the system dialog).
    try {
      final perms = await CallBridge.checkPermissions();
      _isDefaultSms = perms['defaultSms'] == true;
      if (mounted) setState(() {});
    } catch (_) {}

    if (!mounted) return;
    if (!_isDefaultSms) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Default SMS app'),
          content: const Text(
            'If you already selected PYX Food Products as default SMS, tap '
            '“Refresh & send”.\n\n'
            'If not, tap “Set default”, press OK on the Android note, then send again.\n\n'
            'You can also “Send anyway” (may still hit modem errors 16/124).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'anyway'),
              child: const Text('Send anyway'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'set'),
              child: const Text('Set default'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'refresh'),
              child: const Text('Refresh & send'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      if (choice == 'set') {
        await CallBridge.requestDefaultSmsRole();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await _bootstrap();
        if (!_isDefaultSms) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'After Android shows OK, come back and tap Send blast again '
                '(or Refresh & send).',
              ),
            ),
          );
          return;
        }
      } else if (choice == 'refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _bootstrap();
        if (!_isDefaultSms) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Android still reports another default SMS app. '
                'Open system settings → Default SMS app → PYX Food Products → OK.',
              ),
            ),
          );
          return;
        }
      }
      // 'anyway' falls through and sends
    }

    final pages = _smsMeta(AppBrand.brandMessage(body)).pages;
    if (pages >= 4) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Long message ($pages SMS pages)'),
          content: Text(
            'This text uses about $pages SMS segments per recipient. '
            'Long blasts overload the SIM modem and cause code 16/124 failures.\n\n'
            'Tip: use a shorter message for large lists, then send details in Thread.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Edit')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send anyway')),
          ],
        ),
      );
      if (go != true) return;
    }

    if (!await _confirmRateLimit(pasted.length, recipients.length)) return;

    final branded = AppBrand.brandMessage(body);
    const allSims = false;

    if (_scheduledAt != null && _scheduledAt!.isAfter(DateTime.now().add(const Duration(seconds: 5)))) {
      final result = await CallBridge.scheduleSmsBlast(
        addresses: recipients,
        body: branded,
        triggerAtMs: _scheduledAt!.millisecondsSinceEpoch,
        subscriptionId: _subscriptionId,
        allSims: allSims,
        priority: _priority,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['ok'] == true
                ? 'Scheduled blast for ${_scheduledAt!.toLocal()} (${recipients.length} unique)'
                : 'Schedule failed: ${result['error']}',
          ),
        ),
      );
      return;
    }

    await _doSend(recipients, branded);
  }

  Future<void> _doSend(List<String> recipients, String body) async {
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
        subscriptionId: _subscriptionId,
        allSims: false,
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
        attempt: _attempt,
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
      final sent = result['sent'];
      final failed = result['failed'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_attempt > 0 ? '${_attemptLabel(_attempt)} · ' : ''}'
            'Blast ${result['cancelled'] == true ? 'cancelled' : 'done'} · '
            'sent $sent · failed $failed · total ${recipients.length}',
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

  Future<void> _exportHistory() async {
    if (_history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _historyFilter == 'all'
                ? 'No blast history to export yet'
                : 'No blasts for ${_filterLabel()} to export',
          ),
        ),
      );
      return;
    }
    try {
      await BlastHistoryExporter.share(
        jobs: _history,
        label: _filterLabel(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _showHistoryDetail(BlastJob job) async {
    final rows = await appDatabase.recipientsFor(job.id);
    if (!mounted) return;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.72,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '${job.attempt > 0 ? '${_attemptLabel(job.attempt)} · ' : ''}'
                    'Blast · ${job.sent}/${job.total} sent',
                  ),
                  subtitle: Text(
                    '${_formatHistoryDate(job.createdAt)}\n${job.body}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Export this blast',
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await BlastHistoryExporter.share(
                          jobs: [job],
                          label: _formatHistoryDate(job.createdAt)
                              .split(' · ')
                              .first,
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadFailedFromBlast(job);
                      },
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Load failed numbers into Blast'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${rows.length} number${rows.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: rows.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.phone_disabled_outlined,
                          title: 'No numbers saved',
                          message: 'This blast has no recipient rows.',
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final ok = r.status == 'sent';
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                ok
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: ok
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                                size: 20,
                              ),
                              title: Text(r.address),
                              trailing: Text(
                                r.status,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: ok
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

  Widget _historyFilterChip(
    String key,
    String label, {
    Future<void> Function()? onCustom,
  }) {
    final selected = _historyFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) async {
          if (onCustom != null) {
            await onCustom();
          } else {
            await _setHistoryFilter(key);
          }
        },
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        AppSectionHeader(
          'History',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _filterLabel(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Export CSV',
                onPressed: _historyLoading || _history.isEmpty
                    ? null
                    : _exportHistory,
                icon: const Icon(Icons.ios_share_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _historyFilterChip('all', 'All'),
              _historyFilterChip('today', 'Today'),
              _historyFilterChip('yesterday', 'Yesterday'),
              _historyFilterChip('week', '7 days'),
              _historyFilterChip('month', 'This month'),
              _historyFilterChip('day', 'Pick day', onCustom: _pickHistoryDay),
              _historyFilterChip(
                'pickMonth',
                'Pick month',
                onCustom: _pickHistoryMonth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_historyLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _historyFilter == 'all'
                  ? 'No blast history yet. Send a blast to see it here.'
                  : 'No blasts for ${_filterLabel()}. Try another date.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._history.map(
            (h) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  '${h.attempt > 0 ? '${_attemptLabel(h.attempt)} · ' : ''}'
                  '${h.sent}/${h.total} sent · ${h.priority}',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      _formatHistoryDate(h.createdAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      h.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (v == 'open') await _showHistoryDetail(h);
                    if (v == 'failed') await _loadFailedFromBlast(h);
                    if (v == 'export') {
                      try {
                        await BlastHistoryExporter.share(
                          jobs: [h],
                          label: _formatHistoryDate(h.createdAt)
                              .split(' · ')
                              .first,
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Open details')),
                    PopupMenuItem(
                      value: 'failed',
                      child: Text('Load failed numbers'),
                    ),
                    PopupMenuItem(value: 'export', child: Text('Export CSV')),
                  ],
                ),
                onTap: () => _showHistoryDetail(h),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _smsMeta(_message.text);
    final pasted = _parseNumbers(_numbers.text).length;
    final unique = _uniqueRecipients().length;
    final dupes = pasted - unique;
    final scheduleLabel = _scheduledAt == null
        ? 'Send now'
        : '${_scheduledAt!.month}/${_scheduledAt!.day} '
            '${_scheduledAt!.hour.toString().padLeft(2, '0')}:'
            '${_scheduledAt!.minute.toString().padLeft(2, '0')}';

    final simItems = _sims.isEmpty
        ? [const DropdownMenuItem(value: -1, child: Text('Auto — SIM with load + failover'))]
        : _sims
            .map(
              (s) => DropdownMenuItem(
                value: (s['id'] as num?)?.toInt() ?? -1,
                child: Text('${s['label']}'),
              ),
            )
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        if (!_smsSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SmsPermissionHelp(onRequest: _request),
          ),
        if (!_isDefaultSms)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppNoticeBanner(
              icon: Icons.sms_outlined,
              tone: AppNoticeTone.warning,
              message:
                  'Required for reliable sending: set PYX Food Products as the default SMS app. '
                  'Otherwise the modem often returns code 16/124.',
              actionLabel: 'Set',
              onAction: () async {
                await CallBridge.requestDefaultSmsRole();
                await _bootstrap();
              },
            ),
          ),
        if (_sims.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppNoticeBanner(
              icon: Icons.sim_card_outlined,
              tone: AppNoticeTone.info,
              message: _sims.any((s) => s['lastSuccessful'] == true)
                  ? 'Using your SIM card. Prefer Auto or the SIM marked “has load / last OK” under Send via.'
                  : 'Using your SIM card. Send one test from Message first, then pick that SIM (or Auto) here.',
            ),
          ),
        if (_aggressiveOem)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .tertiaryContainer
                  .withValues(alpha: 0.55),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Realme / ColorOS SMS setup'
                      '${_deviceLabel.isEmpty ? '' : ' · $_deviceLabel'}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This phone family often blocks blast SMS unless Preferred SIM '
                      'for SMS is fixed (not Ask every time) and battery is Unrestricted.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_oemTips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ..._oemTips.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $t', style: theme.textTheme.bodySmall),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            await CallBridge.openPreferredSmsSimSettings();
                          },
                          child: const Text('Open SIM settings'),
                        ),
                        if (!_ignoringBattery)
                          FilledButton.tonal(
                            onPressed: () async {
                              await CallBridge.requestIgnoreBatteryOptimizations();
                              await _bootstrap();
                            },
                            child: const Text('Allow unrestricted battery'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recipients ($unique unique'
                '${pasted != unique ? ' · $pasted pasted' : ''})',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _pickContacts,
              icon: const Icon(Icons.contacts, size: 18),
              label: const Text('Contacts'),
            ),
          ],
        ),
        TextField(
          controller: _numbers,
          minLines: 4,
          maxLines: 8,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Mobile numbers (ex. 09178943492) — no limit',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (dupes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$dupes duplicate${dupes == 1 ? '' : 's'} will be skipped (same number twice or 09/+63).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Order follow-up attempt',
            helperText: 'Tag 1st / 2nd / 3rd for undelivered-order reminders',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _attempt,
              items: const [
                DropdownMenuItem(value: 0, child: Text('None (normal blast)')),
                DropdownMenuItem(value: 1, child: Text('1st attempt')),
                DropdownMenuItem(value: 2, child: Text('2nd attempt')),
                DropdownMenuItem(value: 3, child: Text('3rd attempt')),
              ],
              onChanged: (v) => setState(() => _attempt = v ?? 0),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: _sending ? null : _loadFailedFromLast,
              child: const Text('Load failed (last)'),
            ),
            if (_attempt > 0)
              TextButton(
                onPressed: _sending ? null : _trimAlreadyAttempted,
                child: Text('Remove already on ${_attemptLabel(_attempt)}+'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Message', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 10,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'SMS message — type / for quick replies',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        SlashQuickReplyPanel(controller: _message),
        const SizedBox(height: 8),
        Text(
          '${meta.chars} character · ${meta.pages} SMS page · '
          '$unique unique to send'
          '${_attempt > 0 ? ' · ${_attemptLabel(_attempt)}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        QuickTemplatesBar(
          allowSave: true,
          getBodyForSave: () => _message.text,
          onSelect: (body) => setState(() => _message.text = body),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              final recipients = _parseNumbers(_numbers.text);
              CallBridge.openMmsComposer(
                addresses: recipients,
                body: _message.text,
              );
            },
            child: const Text('Open MMS'),
          ),
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
                  helperText: 'Use Auto or the SIM with load — avoids code 16/124',
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
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
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
        if (_sending) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progressTotal == 0
                ? null
                : (_progressIndex + 1) / _progressTotal,
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
        FilledButton.icon(
          onPressed: !_smsSend || _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.campaign_rounded),
          label: Text(_sending ? 'Sending…' : 'Send blast'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        if (_lastResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Last blast status', style: theme.textTheme.titleSmall),
          ..._lastResults.take(20).map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['address']}'),
                  trailing: Text(
                    '${r['status'] ?? (r['ok'] == true ? 'sent' : 'failed')}',
                  ),
                ),
              ),
        ],
        _buildHistorySection(context),
      ],
    );
  }
}
