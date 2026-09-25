import 'dart:async';

import 'package:flutter/material.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';
import '../../widgets/app_ui.dart';
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
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    CallBridge.listen();
    _eventsSub = CallBridge.events.listen((e) {
      if (e['type'] == 'onSmsChanged') {
        _refreshConversations();
      }
    });
    _bootstrap();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
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
      if (_sims.every((s) => (s['id'] as num?)?.toInt() != _subscriptionId)) {
        _subscriptionId = -1;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _refreshConversations() async {
    try {
      final list = await CallBridge.listSmsConversations();
      if (mounted) setState(() => _conversations = list);
    } catch (_) {}
  }

  Future<void> _request() async {
    await CallBridge.requestPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _bootstrap();
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

  Future<void> _send() async {
    final address = _to.text.trim();
    final body = _body.text.trim();
    if (address.isEmpty || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final branded = AppBrand.brandMessage(body);
      final result = await CallBridge.sendSms(
        address: address,
        body: branded,
        subscriptionId: _subscriptionId,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        final sub = result['subscriptionId'];
        final auto = result['autoSelected'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auto && sub != null
                  ? 'Sent via SIM $sub (auto-picked for load)'
                  : 'Message sent — also in Inbox',
            ),
          ),
        );
        _body.clear();
        await _bootstrap();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThreadScreen(address: address),
          ),
        );
        await _refreshConversations();
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
    final theme = Theme.of(context);
    final meta = _smsMeta(_body.text);
    final simItems = _sims.isEmpty
        ? const [DropdownMenuItem(value: -1, child: Text('Auto — try SIM with load'))]
        : _sims
            .map(
              (s) => DropdownMenuItem(
                value: (s['id'] as num?)?.toInt() ?? -1,
                child: Text('${s['label']}'),
              ),
            )
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (!_smsSend) ...[
          SmsPermissionHelp(onRequest: _request),
          const SizedBox(height: 16),
        ],
        AppNoticeBanner(
          icon: Icons.storefront_outlined,
          tone: AppNoticeTone.success,
          message:
              'Messages are sent as “${AppBrand.companyName}: …” so customers see your business name in the text.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _to,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'To',
            hintText: '0917… or +63917…',
            helperText: 'Spaces are cleaned before send',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _body,
          minLines: 5,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 64),
              child: Icon(Icons.edit_outlined),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${meta.chars} characters · ${meta.pages} SMS page${meta.pages == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Send via SIM',
            helperText: 'Auto tries the last working SIM, then the other slot',
            prefixIcon: Icon(Icons.sim_card_outlined),
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
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _sending || !_smsSend ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Sending…' : 'Send message'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 28),
        const AppSectionHeader('Recent conversations'),
        if (_conversations.isEmpty)
          Text(
            'No conversations yet. Send a message — it will show in Inbox too.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ..._conversations.map((c) {
            final address = c['address']?.toString() ?? '';
            final type = c['type']?.toString();
            final body = c['body']?.toString() ?? '';
            final preview = type == 'sent' ? 'You: $body' : body;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(address),
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ThreadScreen(address: address),
                    ),
                  );
                  await _refreshConversations();
                },
              ),
            );
          }),
      ],
    );
  }
}
