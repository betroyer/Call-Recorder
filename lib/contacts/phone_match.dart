/// Shared phone match helpers (align with native PhoneNormalizer.matchKey).
class PhoneMatch {
  PhoneMatch._();

  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return trimmed.replaceAll(' ', '');
    if (digits.length == 11 && digits.startsWith('09')) {
      return '+63${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('63')) {
      return '+$digits';
    }
    return hasPlus ? '+$digits' : digits;
  }

  static String matchKey(String raw) {
    final digits = normalize(raw).replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Unique normalized numbers preserving first-seen order.
  static List<String> uniqueNormalized(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final r in raw) {
      final n = normalize(r.trim());
      if (n.isEmpty) continue;
      final key = matchKey(n);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(n);
    }
    return out;
  }
}
