import 'package:flutter/material.dart';

import '../features/messages/inbox_screen.dart';
import '../features/messages/compose_screen.dart';
import '../features/messages/sms_blast_screen.dart';
import '../prototype/prototype_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Record', 'Inbox', 'Message', 'SMS Blast'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const PrototypeScreen(embedded: true),
      const InboxScreen(),
      const ComposeScreen(),
      const SmsBlastScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
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
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Message',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Blast',
          ),
        ],
      ),
    );
  }
}
