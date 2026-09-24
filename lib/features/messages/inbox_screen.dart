import 'dart:async';

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
  bool _defaultSms = false;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    CallBridge.listen();
    _eventsSub = CallBridge.events.listen((e) {
      if (e['type'] == 'onSmsChanged') {
        _load(silent: true);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final perms = await CallBridge.checkPermissions();
      _smsRead = perms['smsRead'] == true;
      _defaultSms = perms['defaultSms'] == true;
      if (!_smsRead) {
        if (mounted) {
          setState(() {
            _loading = false;
            _items = const [];
          });
        }
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

  Future<void> _setRead(Map<String, dynamic> m, bool read, {bool silent = false}) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    final result = await CallBridge.setSmsRead(id: id, read: read);
    if (!mounted) return;
    if (result['ok'] == true) {
      setState(() {
        final i = _items.indexWhere((e) => (e['id'] as num?)?.toInt() == id);
        if (i >= 0) {
          _items = List<Map<String, dynamic>>.from(_items);
          _items[i] = {..._items[i], 'read': read};
        }
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(read ? 'Marked as read' : 'Marked as unread')),
        );
      }
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['error']}'),
          action: SnackBarAction(
            label: 'Default SMS',
            onPressed: () => CallBridge.requestDefaultSmsRole(),
          ),
        ),
      );
    }
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

  Widget _defaultSmsBanner() {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.secondaryContainer,
      leading: const Icon(Icons.sms_outlined),
      title: const Text(
        'For reliable incoming customer SMS, set CallVault as the default SMS app.',
      ),
      trailing: TextButton(
        onPressed: () async {
          await CallBridge.requestDefaultSmsRole();
          await _load(silent: true);
        },
        child: const Text('Set'),
      ),
    );
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
        onRefresh: () => _load(),
        child: ListView(
          children: [
            if (!_defaultSms) _defaultSmsBanner(),
            const SizedBox(height: 120),
            const Center(child: Text('No inbox messages yet.')),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Customer replies appear here when SMS arrives.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        itemCount: _items.length + (_defaultSms ? 0 : 1),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (!_defaultSms && index == 0) {
            return _defaultSmsBanner();
          }
          final m = _items[_defaultSms ? index : index - 1];
          final address = m['address']?.toString() ?? '';
          final body = m['body']?.toString() ?? '';
          final isRead = m['read'] == true;
          final titleStyle = isRead
              ? theme.textTheme.titleMedium
              : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
          final bodyStyle = isRead
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isRead
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primaryContainer,
              child: Text(address.isNotEmpty ? address[0] : '?'),
            ),
            title: Text(address, style: titleStyle),
            subtitle: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  _formatTime(m['dateMs']),
                  style: theme.textTheme.bodySmall,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'read') _setRead(m, true);
                    if (value == 'unread') _setRead(m, false);
                  },
                  itemBuilder: (context) => [
                    if (!isRead)
                      const PopupMenuItem(value: 'read', child: Text('Mark as read')),
                    if (isRead)
                      const PopupMenuItem(
                        value: 'unread',
                        child: Text('Mark as unread'),
                      ),
                  ],
                ),
              ],
            ),
            onTap: () async {
              if (!isRead) {
                await _setRead(m, true, silent: true);
              }
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ThreadScreen(address: address),
                ),
              );
              await _load();
            },
            onLongPress: () async {
              final choice = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.mark_email_read_outlined),
                        title: const Text('Mark as read'),
                        onTap: () => Navigator.pop(ctx, 'read'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.mark_email_unread_outlined),
                        title: const Text('Mark as unread'),
                        onTap: () => Navigator.pop(ctx, 'unread'),
                      ),
                    ],
                  ),
                ),
              );
              if (choice == 'read') await _setRead(m, true);
              if (choice == 'unread') await _setRead(m, false);
            },
          );
        },
      ),
    );
  }
}
