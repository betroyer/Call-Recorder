import 'package:flutter/material.dart';

import 'app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallVaultPrototypeApp());
}

class CallVaultPrototypeApp extends StatelessWidget {
  const CallVaultPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallVault',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
