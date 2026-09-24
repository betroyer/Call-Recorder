import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';
import 'sms_permission_help.dart';
import 'thread_screen.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _to = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _sims = const [];
  int _subscriptionId = -1;
  bool _sending = false;
  bool _smsSend = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _to.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final perms = await CallBridge.checkPermissions();
    _smsSend = perms['smsSend'] == true;
    try {
      _sims = await CallBridge.listSims();
      _conversations = await CallBridge.listSmsConversations();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _request() async {
    await CallBridge.requestPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _bootstrap();
  }

  ({int chars, int pages}) _smsMeta(String text) {
    // Rough GSM-7 vs Unicode page estimate.
    final isGsm = text.codeUnits.every((c) => c <= 127);
    final limit = isGsm ? 160 : 70;
    final multi = isGsm ? 153 : 67;
    final len = text.length;
    if (len == 0) return (chars: 0, pages: 1);
    if (len <= limit) return (chars: len, pages: 1);
    return (chars: len, pages: ((len + multi - 1) ~/ multi));
  }

  Future<void> _send() async {
    final address = _to.text.trim();
    final body = _body.text.trim();
    if (address.isEmpty || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await CallBridge.sendSms(
        address: address,
        body: body,
        subscriptionId: _subscriptionId,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent')),
        );
        _body.clear();
        await _bootstrap();
      } else {
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
    final meta = _smsMeta(_body.text);
    final simItems = _sims.isEmpty
        ? const [DropdownMenuItem(value: -1, child: Text('Default SIM'))]
        : _sims
            .map(
              (s) => DropdownMenuItem(
                value: (s['id'] as num?)?.toInt() ?? -1,
                child: Text('${s['label']}'),
              ),
            )
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_smsSend)
          SmsPermissionHelp(onRequest: _request),
        if (!_smsSend) const SizedBox(height: 12),
        TextField(
          controller: _to,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'To',
            hintText: '0917…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text('${meta.chars} character  ${meta.pages} SMS page'),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Send via',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending || !_smsSend ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            minimumSize: const Size.fromHeight(48),
          ),
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('SEND'),
        ),
        const SizedBox(height: 24),
        Text('Recent', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_conversations.isEmpty)
          const Text('No conversations yet.')
        else
          ..._conversations.map((c) {
            final address = c['address']?.toString() ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(address),
              subtitle: Text(
                c['body']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThreadScreen(address: address),
                  ),
                );
              },
            );
          }),
      ],
    );
  }
}
