import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../branding.dart';
import '../../bridge/call_bridge.dart';
import '../../widgets/app_ui.dart';

const _kOnboardingDone = 'pyx_onboarding_done_v1';

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) == true;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

/// First-run setup: permissions → default SMS → SIM with load.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  Map<String, bool> _perms = const {};
  List<Map<String, dynamic>> _sims = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final perms = await CallBridge.checkPermissions();
      final sims = await CallBridge.listSims();
      if (!mounted) return;
      setState(() {
        _perms = perms;
        _sims = sims;
      });
    } catch (_) {}
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _next() async {
    if (_index >= 3) {
      await _finish();
      return;
    }
    await _page.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _requestPermissions() async {
    setState(() => _busy = true);
    try {
      await CallBridge.requestPermissions();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDefaultSms() async {
    setState(() => _busy = true);
    try {
      await CallBridge.requestDefaultSmsRole();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stepCard({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _permRow(String label, bool ok) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: ok ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final smsOk = _perms['smsSend'] == true && _perms['smsRead'] == true;
    final contactsOk = _perms['contacts'] == true;
    final defaultOk = _perms['defaultSms'] == true;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(AppBrand.appName),
        actions: [
          if (_index < 3)
            TextButton(
              onPressed: _busy ? null : _finish,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: List.generate(4, (i) {
                final active = i <= _index;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: active ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (i) {
                setState(() => _index = i);
                _refresh();
              },
              children: [
                _stepCard(
                  icon: Icons.storefront_rounded,
                  title: 'Welcome to ${AppBrand.companyName}',
                  body:
                      'Send and receive customer SMS from one place — with your business name in every outbound text.',
                  children: [
                    AppNoticeBanner(
                      icon: Icons.campaign_outlined,
                      tone: AppNoticeTone.success,
                      message:
                          'Blasts, Inbox, and quick templates are ready after a short setup.',
                    ),
                  ],
                ),
                _stepCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Allow permissions',
                  body:
                      'SMS and Contacts let you send messages and show customer names in Inbox.',
                  children: [
                    _permRow('Send & read SMS', smsOk),
                    _permRow('Contacts (names in Inbox)', contactsOk),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _requestPermissions,
                      child: Text(_busy ? 'Requesting…' : 'Allow permissions'),
                    ),
                  ],
                ),
                _stepCard(
                  icon: Icons.sms_outlined,
                  title: 'Default SMS app',
                  body:
                      'For reliable incoming customer replies, set ${AppBrand.appName} as the default SMS app.',
                  children: [
                    _permRow('Default SMS app', defaultOk),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _requestDefaultSms,
                      child: Text(defaultOk ? 'Already set' : 'Set as default SMS'),
                    ),
                    if (defaultOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'You can change this later in system settings.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                _stepCard(
                  icon: Icons.sim_card_outlined,
                  title: 'Use the SIM with load',
                  body:
                      'On dual-SIM phones, choose Auto or the slot that has SMS load. The app retries the other SIM if send fails.',
                  children: [
                    if (_sims.isEmpty)
                      Text(
                        'No SIMs detected yet. Insert a SIM with load, then open Message.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ..._sims.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: scheme.outlineVariant),
                            ),
                            leading: const Icon(Icons.sim_card_outlined),
                            title: Text('${s['label'] ?? 'SIM'}'),
                            subtitle: Text('ID ${s['id']}'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    AppNoticeBanner(
                      icon: Icons.tips_and_updates_outlined,
                      message:
                          'Under Message → Send via SIM, leave Auto unless you know which slot has load.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                onPressed: _busy ? null : _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_index >= 3 ? 'Start using the app' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
