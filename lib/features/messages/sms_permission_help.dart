import 'package:flutter/material.dart';

import '../../bridge/call_bridge.dart';

/// Explains Android "restricted settings" block for sideloaded SMS apps.
class SmsPermissionHelp extends StatelessWidget {
  const SmsPermissionHelp({
    super.key,
    required this.onRequest,
    this.compact = false,
  });

  final VoidCallback onRequest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SMS blocked (restricted permission)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              compact
                  ? 'Sideloaded apps need “Allow restricted settings”, then SMS permission.'
                  : 'Android blocked SMS for this sideloaded APK.\n\n'
                      '1. Open the system dialog → Learn how to allow access, or:\n'
                      '2. Settings → Apps → CallVault Prototype → ⋮ (top right)\n'
                      '3. Tap Allow restricted settings\n'
                      '4. Come back here → Grant SMS / Request permissions\n'
                      '5. Allow SMS when Android asks',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onRequest,
                  child: const Text('Grant SMS'),
                ),
                OutlinedButton(
                  onPressed: () => CallBridge.openAppSettings(),
                  child: const Text('Open App Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
