import 'package:flutter/material.dart';

import 'branding.dart';
import 'theme/app_theme.dart';
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
      title: AppBrand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
