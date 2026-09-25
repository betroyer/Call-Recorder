import 'package:flutter/material.dart';

import 'send_result.dart';

/// Persistent send outcome under Message / Thread composers.
class SendStatusBanner extends StatelessWidget {
  const SendStatusBanner({
    super.key,
    required this.result,
    this.onDismiss,
    this.onRetry,
  });

  final SendResult result;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = result.ok;
    final bg = ok
        ? scheme.primaryContainer.withValues(alpha: 0.65)
        : scheme.errorContainer.withValues(alpha: 0.55);
    final fg = ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              size: 22,
              color: fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
                  ),
                  if (!ok && onRetry != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, size: 20, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small label under an outgoing bubble.
class MessageSendLabel extends StatelessWidget {
  const MessageSendLabel({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'sent' => ('Sent', scheme.onSurfaceVariant),
      'failed' => ('Failed', scheme.error),
      'outbox' || 'queued' => ('Sending…', scheme.onSurfaceVariant),
      _ => (status, scheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: status == 'failed' ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
    );
  }
}
