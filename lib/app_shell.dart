import 'package:flutter/material.dart';

import 'branding.dart';
import 'bridge/call_bridge.dart';
import 'features/messages/inbox_screen.dart';
import 'features/messages/compose_screen.dart';
import 'features/messages/sms_blast_screen.dart';
import 'features/notes/notes_screen.dart';
import 'prototype/prototype_screen.dart';
import 'widgets/app_ui.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Record', 'Inbox', 'Message', 'SMS Blast', 'Notes'];

  @override
  void initState() {
    super.initState();
    CallBridge.listen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = <Widget>[
      const PrototypeScreen(embedded: true),
      const InboxScreen(),
      const ComposeScreen(),
      const SmsBlastScreen(),
      const NotesScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        leadingWidth: 52,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: BrandLogo(size: 40),
        ),
        title: Text(_titles[_index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                AppBrand.companyName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Message',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Blast',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2_rounded),
            label: 'Notes',
          ),
        ],
      ),
    );
  }
}
