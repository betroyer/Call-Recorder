/// Display helpers for SMS rows that may include a resolved [contactName].
class ContactDisplay {
  ContactDisplay._();

  static String title(Map<String, dynamic> row, {String addressKey = 'address'}) {
    final name = row['contactName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return row[addressKey]?.toString() ?? '';
  }

  static String? subtitleNumber(Map<String, dynamic> row, {String addressKey = 'address'}) {
    final name = row['contactName']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    final address = row[addressKey]?.toString() ?? '';
    return address.isEmpty ? null : address;
  }

  static String avatarLetter({String? name, String? address}) {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) {
      return n.substring(0, 1).toUpperCase();
    }
    final digits = (address ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) return digits[digits.length - 1];
    final a = address?.trim() ?? '';
    return a.isNotEmpty ? a[0].toUpperCase() : '?';
  }
}
