/// Parsed result from native [CallBridge.sendSms].
class SendResult {
  const SendResult({
    required this.ok,
    required this.status,
    this.error,
    this.subscriptionId,
    this.autoSelected = false,
    this.attempts,
  });

  final bool ok;
  final String status;
  final String? error;
  final int? subscriptionId;
  final bool autoSelected;
  final int? attempts;

  factory SendResult.fromMap(Map<String, dynamic> map) {
    return SendResult(
      ok: map['ok'] == true,
      status: map['status']?.toString() ?? (map['ok'] == true ? 'sent' : 'failed'),
      error: map['error']?.toString(),
      subscriptionId: (map['subscriptionId'] as num?)?.toInt(),
      autoSelected: map['autoSelected'] == true,
      attempts: (map['attempts'] as num?)?.toInt(),
    );
  }

  String get headline => ok ? 'Sent' : 'Not sent';

  String get detail {
    if (ok) {
      final sim = subscriptionId;
      if (autoSelected && sim != null) {
        return 'Delivered to the carrier via SIM $sim (auto-picked for load).';
      }
      if (sim != null && sim >= 0) {
        return 'Accepted by the carrier via SIM $sim.';
      }
      return 'Accepted by the carrier.';
    }
    final err = error?.trim();
    if (err != null && err.isNotEmpty) return err;
    return 'Send failed. Check SIM load and try again.';
  }
}
