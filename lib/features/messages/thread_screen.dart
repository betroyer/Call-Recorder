import 'dart:async';

import 'package:flutter/material.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.address});

  final String address;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  List<Map<String, dynamic>> _messages = const [];
  final _reply = TextEditingController();
  bool _sending = false;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    CallBridge.listen();
    _eventsSub = CallBridge.events.listen((e) {
      if (e['type'] == 'onSmsChanged') {
        final addr = e['address']?.toString();
        if (addr == null || addr.isEmpty || addr == widget.address) {
          _load();
        }
      }
    });
    _load(markRead: true);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load({bool markRead = false}) async {
    final list = await CallBridge.listSmsThread(widget.address);
    if (markRead) {
      await CallBridge.setSmsThreadRead(address: widget.address, read: true);
    }
    if (mounted) setState(() => _messages = list);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final mine = m['type']?.toString() == 'sent';
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m['body']?.toString() ?? ''),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
