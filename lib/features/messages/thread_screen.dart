import 'dart:async';

import 'package:flutter/material.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';
import 'quick_templates_bar.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    required this.address,
    this.contactName,
  });

  final String address;
  final String? contactName;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  List<Map<String, dynamic>> _messages = const [];
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _contactName;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _contactName = widget.contactName?.trim().isNotEmpty == true
        ? widget.contactName!.trim()
        : null;
    CallBridge.listen();
    _eventsSub = CallBridge.events.listen((e) {
      if (e['type'] == 'onSmsChanged') {
        final addr = e['address']?.toString();
        if (addr == null || addr.isEmpty || addr == widget.address) {
          _load();
        }
      }
    });
    _resolveName();
    _load(markRead: true);
  }

  Future<void> _resolveName() async {
    if (_contactName != null) return;
    final name = await CallBridge.resolveContactName(widget.address);
    if (!mounted || name == null) return;
    setState(() => _contactName = name);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool markRead = false}) async {
    final list = await CallBridge.listSmsThread(widget.address);
    if (markRead) {
      await CallBridge.setSmsThreadRead(address: widget.address, read: true);
    }
    if (mounted) {
      setState(() => _messages = list);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _setThreadRead(bool read) async {
    final result = await CallBridge.setSmsThreadRead(
      address: widget.address,
      read: read,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['ok'] == true
              ? (read ? 'Thread marked as read' : 'Thread marked as unread')
              : '${result['error']}',
        ),
        action: result['ok'] == true
            ? null
            : SnackBarAction(
                label: 'Default SMS',
                onPressed: () => CallBridge.requestDefaultSmsRole(),
              ),
      ),
    );
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await CallBridge.sendSms(
        address: widget.address,
        body: AppBrand.brandMessage(body),
      );
      if (result['ok'] == true) {
        _reply.clear();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sent — synced to Inbox')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['error']}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(dynamic ms) {
    final n = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (n <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(n);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _contactName ?? widget.address,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_contactName != null)
              Text(
                widget.address,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'read') _setThreadRead(true);
              if (value == 'unread') _setThreadRead(false);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'read', child: Text('Mark as read')),
              PopupMenuItem(value: 'unread', child: Text('Mark as unread')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages in this thread yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final mine = m['type']?.toString() == 'sent';
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            decoration: BoxDecoration(
                              color: mine
                                  ? scheme.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                              border: mine
                                  ? null
                                  : Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  m['body']?.toString() ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: mine
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(m['dateMs']),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: mine
                                        ? scheme.onPrimary.withValues(alpha: 0.75)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Material(
            color: Colors.white,
            elevation: 6,
            shadowColor: Colors.black26,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuickTemplatesBar(
                      showHeader: false,
                      allowDelete: false,
                      onSelect: (body) => setState(() => _reply.text = body),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            decoration: const InputDecoration(
                              hintText: 'Type a reply…',
                              isDense: true,
                            ),
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
