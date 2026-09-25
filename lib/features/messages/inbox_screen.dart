import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';
import '../../contacts/contact_display.dart';
import '../../widgets/app_ui.dart';
import 'sms_permission_help.dart';
import 'thread_screen.dart';

/// Conversation inbox: shows both your sent messages and customer replies.
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
      final list = await CallBridge.listSmsConversations();
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

  Future<void> _setThreadRead(Map<String, dynamic> m, bool read, {bool silent = false}) async {
    final address = m['address']?.toString() ?? '';
    if (address.isEmpty) return;
    final result = await CallBridge.setSmsThreadRead(address: address, read: read);
    if (!mounted) return;
    if (result['ok'] == true) {
      setState(() {
        final i = _items.indexWhere((e) => e['address']?.toString() == address);
        if (i >= 0) {
          _items = List<Map<String, dynamic>>.from(_items);
          _items[i] = {
            ..._items[i],
            'read': read,
            'unreadCount': read ? 0 : (_items[i]['unreadCount'] ?? 1),
          };
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

  String _preview(Map<String, dynamic> m) {
    final body = m['body']?.toString() ?? '';
    if (m['type']?.toString() == 'sent') {
      return body.isEmpty ? 'You: (empty)' : 'You: $body';
    }
    return body;
  }

  Widget _defaultSmsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AppNoticeBanner(
        icon: Icons.sms_outlined,
        message:
            'For reliable incoming customer SMS, set PYX Food Products as the default SMS app.',
        actionLabel: 'Set',
        onAction: () async {
          await CallBridge.requestDefaultSmsRole();
          await _load(silent: true);
        },
      ),
    );
  }

  Future<void> _openThread(Map<String, dynamic> m) async {
    final address = m['address']?.toString() ?? '';
    final contactName = m['contactName']?.toString();
    final isRead = m['read'] == true;
    if (!isRead) {
      await _setThreadRead(m, true, silent: true);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadScreen(
          address: address,
          contactName: contactName,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Couldn’t load inbox',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          children: [
            if (!_defaultSms) _defaultSmsBanner(),
            AppEmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'Send from Message, or wait for a customer reply — both appear here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length + (_defaultSms ? 0 : 1),
        separatorBuilder: (_, index) {
          if (!_defaultSms && index == 0) return const SizedBox.shrink();
          return Divider(height: 1, indent: 72, color: scheme.outlineVariant);
        },
        itemBuilder: (context, index) {
          if (!_defaultSms && index == 0) {
            return _defaultSmsBanner();
          }
          final m = _items[_defaultSms ? index : index - 1];
          final address = m['address']?.toString() ?? '';
          final contactName = m['contactName']?.toString().trim();
          final title = ContactDisplay.title(m);
          final numberSubtitle = ContactDisplay.subtitleNumber(m);
          final isRead = m['read'] == true;
          final avatarLetter = ContactDisplay.avatarLetter(
            name: contactName,
            address: address,
          );

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openThread(m),
              onLongPress: () async {
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
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
                if (choice == 'read') await _setThreadRead(m, true);
                if (choice == 'unread') await _setThreadRead(m, false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isRead
                          ? scheme.surfaceContainerHighest
                          : scheme.primaryContainer,
                      foregroundColor: isRead
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimaryContainer,
                      child: Text(
                        avatarLetter,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight:
                                        isRead ? FontWeight.w500 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(m['dateMs']),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'read') _setThreadRead(m, true);
                                  if (value == 'unread') _setThreadRead(m, false);
                                },
                                itemBuilder: (context) => [
                                  if (!isRead)
                                    const PopupMenuItem(
                                      value: 'read',
                                      child: Text('Mark as read'),
                                    ),
                                  if (isRead)
                                    const PopupMenuItem(
                                      value: 'unread',
                                      child: Text('Mark as unread'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (numberSubtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              numberSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _preview(m),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isRead
                                        ? scheme.onSurfaceVariant
                                        : scheme.onSurface,
                                    fontWeight:
                                        isRead ? FontWeight.w400 : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
