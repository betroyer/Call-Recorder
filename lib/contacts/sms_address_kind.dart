/// Classifies SMS addresses so Inbox can hide carrier / brand promos.
class SmsAddressKind {
  SmsAddressKind._();

  /// True for real mobile/landline-style numbers (not TNT, GCash, short codes).
  static bool isLikelyPerson(String? address) {
    final raw = address?.trim() ?? '';
    if (raw.isEmpty) return false;
    // Alphanumeric sender IDs: TNT, GCash, Banks, etc.
    if (RegExp(r'[A-Za-z]').hasMatch(raw)) return false;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // Short codes / service numbers are usually under 10 digits.
    if (digits.length < 10) return false;
    return true;
  }

  static bool isInContacts(Map<String, dynamic> row) {
    final name = row['contactName']?.toString().trim();
    return name != null && name.isNotEmpty;
  }

  static bool isUnread(Map<String, dynamic> row) => row['read'] != true;

  static bool isToday(Map<String, dynamic> row) {
    final ms = row['dateMs'];
    final n = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (n <= 0) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(n);
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}
