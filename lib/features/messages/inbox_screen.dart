import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';
import '../../contacts/contact_display.dart';
import '../../contacts/sms_address_kind.dart';
import '../../widgets/app_ui.dart';
import 'sms_permission_help.dart';
import 'thread_screen.dart';

enum _InboxScope { people, contacts, unread, today, all }

/// Conversation inbox: shows both your sent messages and customer replies.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _items = const [];
  final _search = TextEditingController();
  String _query = '';
  /// Default hides TNT / GCash / short-code promo senders.
  _InboxScope _scope = _InboxScope.people;
  bool _loading = true;
  String? _error;
  bool _smsRead = false;
  bool _defaultSms = false;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    CallBridge.listen();
    _search.addListener(() {
      final next = _search.text;
      if (next == _query) return;
      setState(() => _query = next);
    });
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
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _scoped {
    switch (_scope) {
      case _InboxScope.people:
        return _items
            .where((m) => SmsAddressKind.isLikelyPerson(m['address']?.toString()))
            .toList();
      case _InboxScope.contacts:
        return _items.where(SmsAddressKind.isInContacts).toList();
      case _InboxScope.unread:
        return _items.where(SmsAddressKind.isUnread).toList();
      case _InboxScope.today:
        return _items.where(SmsAddressKind.isToday).toList();
      case _InboxScope.all:
        return _items;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final base = _scoped;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    return base.where((m) {
      final name = m['contactName']?.toString().toLowerCase() ?? '';
      final address = m['address']?.toString().toLowerCase() ?? '';
      final body = m['body']?.toString().toLowerCase() ?? '';
      if (name.contains(q) || address.contains(q) || body.contains(q)) {
        return true;
      }
      if (qDigits.isNotEmpty) {
        final addressDigits = address.replaceAll(RegExp(r'\D'), '');
        if (addressDigits.contains(qDigits)) return true;
      }
      return false;
    }).toList();
  }

  String get _scopeEmptyTitle => switch (_scope) {
        _InboxScope.people => 'No people chats here',
        _InboxScope.contacts => 'No contact chats',
        _InboxScope.unread => 'No unread chats',
        _InboxScope.today => 'Nothing today',
        _InboxScope.all => 'No conversations yet',
      };

  String get _scopeEmptyMessage => switch (_scope) {
        _InboxScope.people =>
          'Promo senders like TNT / GCash are hidden. Switch to All to see everything.',
        _InboxScope.contacts =>
          'Only numbers saved in Contacts appear here. Save a customer, or switch to People.',
        _InboxScope.unread => 'You’re caught up — or switch to People / All.',
        _InboxScope.today => 'No SMS activity today under this filter.',
        _InboxScope.all =>
          'Send from Message, or wait for a customer reply — both appear here.',
      };

  Widget _scopeChips() {
    Widget chip(_InboxScope scope, String label) {
      final selected = _scope == scope;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _scope = scope),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        children: [
          chip(_InboxScope.people, 'People'),
          chip(_InboxScope.contacts, 'Contacts'),
          chip(_InboxScope.unread, 'Unread'),
          chip(_InboxScope.today, 'Today'),
          chip(_InboxScope.all, 'All'),
        ],
      ),
    );
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

  Widget _searchBar(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search name, number, or message',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _defaultSmsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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

  Widget _conversationTile(
    BuildContext context,
    Map<String, dynamic> m,
    ThemeData theme,
    ColorScheme scheme,
  ) {
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

    final visible = _filtered;
    final searching = _query.trim().isNotEmpty;
    final showBanner = !_defaultSms;

    return Column(
      children: [
        _searchBar(theme, scheme),
        _scopeChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (showBanner) _defaultSmsBanner(),
                      AppEmptyState(
                        icon: searching
                            ? Icons.search_off_rounded
                            : Icons.filter_alt_outlined,
                        title: searching ? 'No matches' : _scopeEmptyTitle,
                        message: searching
                            ? 'Nothing matched “${_query.trim()}”. Try a name, number, or word from the last message.'
                            : _scopeEmptyMessage,
                        action: searching
                            ? TextButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                child: const Text('Clear search'),
                              )
                            : _scope != _InboxScope.people
                                ? TextButton(
                                    onPressed: () =>
                                        setState(() => _scope = _InboxScope.people),
                                    child: const Text('Show People'),
                                  )
                                : TextButton(
                                    onPressed: () =>
                                        setState(() => _scope = _InboxScope.all),
                                    child: const Text('Show All'),
                                  ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + (showBanner ? 1 : 0),
                    separatorBuilder: (_, index) {
                      if (showBanner && index == 0) {
                        return const SizedBox.shrink();
                      }
                      return Divider(
                        height: 1,
                        indent: 72,
                        color: scheme.outlineVariant,
                      );
                    },
                    itemBuilder: (context, index) {
                      if (showBanner && index == 0) {
                        return _defaultSmsBanner();
                      }
                      final m = visible[showBanner ? index - 1 : index];
                      return _conversationTile(context, m, theme, scheme);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
