import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';
import 'sms_permission_help.dart';
import 'thread_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  bool _smsRead = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final perms = await CallBridge.checkPermissions();
      _smsRead = perms['smsRead'] == true;
      if (!_smsRead) {
        setState(() {
          _loading = false;
          _items = const [];
        });
        return;
      }
      final list = await CallBridge.listSmsInbox();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestSms() async {
    await CallBridge.requestPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _load();
  }

  String _formatTime(dynamic ms) {
    final n = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (n <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(n);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_smsRead) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SmsPermissionHelp(onRequest: _requestSms),
        ],
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No inbox messages yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final m = _items[index];
          final address = m['address']?.toString() ?? '';
          final body = m['body']?.toString() ?? '';
          return ListTile(
            leading: CircleAvatar(
              child: Text(address.isNotEmpty ? address[0] : '?'),
            ),
            title: Text(address),
            subtitle: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatTime(m['dateMs']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ThreadScreen(address: address),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
