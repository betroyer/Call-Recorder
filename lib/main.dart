import 'package:flutter/material.dart';

import 'branding.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallVaultPrototypeApp());
}

class CallVaultPrototypeApp extends StatefulWidget {
  const CallVaultPrototypeApp({super.key});

  @override
  State<CallVaultPrototypeApp> createState() => _CallVaultPrototypeAppState();
}

class _CallVaultPrototypeAppState extends State<CallVaultPrototypeApp> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadGate();
  }

  Future<void> _loadGate() async {
    final done = await isOnboardingDone();
    if (!mounted) return;
    setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _onboardingDone;
    return MaterialApp(
      title: AppBrand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ready == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : ready
              ? const AppShell()
              : OnboardingScreen(
                  onFinished: () => setState(() => _onboardingDone = true),
                ),
    );
  }
}
