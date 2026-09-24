/// Business branding for PYX Food Products.
///
/// Note: Regular SIM SMS always shows your phone number as the "From" on the
/// customer's phone. We brand the message body so they still see the company name.
/// True alphanumeric sender IDs (name instead of number) require a business SMS gateway.
class AppBrand {
  static const String companyName = 'PYX Food Products';
  static const String appName = 'PYX Food Products';

  /// Short ID for future SMS-gateway alphanumeric sender (max ~11 chars on many carriers).
  static const String smsSenderId = 'PYXFood';

  /// Prefix outbound SMS so customers see the business name in the message text.
  static String brandMessage(String body, {bool enabled = true}) {
    final trimmed = body.trim();
    if (!enabled || trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith(companyName) || trimmed.startsWith('[$companyName]')) {
      return trimmed;
    }
    return '$companyName:\n$trimmed';
  }
}
