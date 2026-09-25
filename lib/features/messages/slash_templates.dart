/// PYX Food Products slash quick-replies (`/` picker).
class SlashTemplate {
  const SlashTemplate({
    required this.keyword,
    required this.title,
    required this.body,
    this.aliases = const [],
  });

  /// Primary trigger without leading slash, e.g. `hmparagis`.
  final String keyword;
  final String title;
  final String body;
  final List<String> aliases;

  List<String> get allKeys => [keyword, ...aliases];

  String resolvedBody([DateTime? now]) {
    final d = now ?? DateTime.now();
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return body
        .trim()
        .replaceAll('{{DATE}}', date)
        .replaceAll('Current date', date)
        .replaceAll('2026-09-25', date);
  }
}

class SlashTemplates {
  SlashTemplates._();

  static const List<SlashTemplate> all = [
    SlashTemplate(
      keyword: 'hmparagis',
      title: 'Flash sale — Paragis',
      body: _hmParagis,
    ),
    SlashTemplate(
      keyword: 'hmhoney',
      title: 'Honey bundles',
      body: _hmHoney,
    ),
    SlashTemplate(
      keyword: 'hmcacao',
      title: 'Flash sale — Cacao',
      body: _hmCacao,
    ),
    SlashTemplate(
      keyword: 'hmblackrice',
      title: 'Black rice coffee',
      body: _hmBlackRice,
    ),
    SlashTemplate(
      keyword: 'delivery',
      title: 'ETA / Delivery',
      body: _delivery,
    ),
    SlashTemplate(
      keyword: 'benefitshoney',
      title: 'Benefits — Honey',
      aliases: ['benifitshoney'],
      body: _benefitsHoney,
    ),
    SlashTemplate(
      keyword: 'benefitsparagis',
      title: 'Benefits — Paragis',
      aliases: ['benifitsparagis'],
      body: _benefitsParagis,
    ),
    SlashTemplate(
      keyword: 'benefitscacao',
      title: 'Benefits — Cacao',
      aliases: ['benifitscacao'],
      body: _benefitsCacao,
    ),
    SlashTemplate(
      keyword: 'benefitsblackrice',
      title: 'Benefits — Black rice',
      body: _benefitsBlackRice,
    ),
    SlashTemplate(
      keyword: 'fda',
      title: 'FDA certification',
      body: _fda,
    ),
    SlashTemplate(
      keyword: 'delivered',
      title: 'Delivered thanks',
      body: _delivered,
    ),
  ];

  /// Active `/query` at end of [text], or null if picker should hide.
  static String? activeQuery(String text) {
    final m = RegExp(r'(?:^|\s)/([a-zA-Z0-9_]*)$').firstMatch(text);
    if (m == null) return null;
    return m.group(1)!.toLowerCase();
  }

  static List<SlashTemplate> filter(String query) {
    final q = query.toLowerCase();
    if (q.isEmpty) return all;
    return all.where((t) {
      return t.allKeys.any((k) => k.toLowerCase().startsWith(q)) ||
          t.title.toLowerCase().contains(q);
    }).toList();
  }

  /// Replace the trailing `/query` with [replacement].
  static String apply(String text, String replacement) {
    final m = RegExp(r'(^|\s)/([a-zA-Z0-9_]*)$').firstMatch(text);
    if (m == null) return replacement;
    final prefix = text.substring(0, m.start) + (m.group(1) ?? '');
    return '$prefix$replacement';
  }
}

// --- Bodies ---

const _hmParagis = '''
⚡🔥𝐅𝐋𝐀𝐒𝐇 𝐒𝐀𝐋𝐄 𝐓𝐇𝐈𝐒 𝟐𝟒 𝐇𝐎𝐔𝐑𝐒 𝐎𝐍𝐋𝐘🔥⚡
𝐓𝐎𝐃𝐀𝐘: {{DATE}}
❌B̶E̶F̶O̶R̶E̶ ̶P̶R̶I̶C̶E̶:̶ ̶1̶9̶9̶9̶❌
✅𝗡𝗢𝗪✅
📌🔥 ₱𝟒𝟗𝟗 + ₱𝟔𝟎 Shipping Fee= 1 Pouch Paragis Tea / 24 Tea Bags
📌🔥 ₱𝟖𝟗𝟗 = Buy 1 Take 1 (2 Pouch) Paragis Tea / 48 Tea Bags   (FREE SHIPPING)
📌🔥  ₱𝟏𝟏𝟗𝟗 =  Buy 1 Take 2 (3 Pouch) Paragis Tea / 72 Tea Bags ( FREE SHIPPING)
or you may also try: BUNDLE with 250ml HONEY (FREE SHIPPING)
📌🔥 1 Pouch + 1 Honey =₱𝟕𝟗𝟗
📌🔥 2 Pouch + 1 Honey =₱𝟏𝟏𝟒𝟗
📌🔥 3 Pouch + 1 Honey = ₱𝟏𝟒𝟒𝟗  𝟕𝟐 𝐓𝐞𝐚 𝐁𝐚𝐠𝐬 + 𝐅𝐑𝐄𝐄𝐁𝐈𝐄𝐒 (𝐁𝐄𝐒𝐓𝐒𝐄𝐋𝐋𝐄𝐑)🔥🔥
*1 Pouch contains 24 teabag
''';

const _hmHoney = '''
𝐁𝐔𝐘 𝐌𝐎𝐑𝐄 𝐆𝐄𝐓 𝐌𝐎𝐑𝐄 𝐓𝐇𝐀𝐍 𝟐𝟎% 𝐃𝐈𝐒𝐂𝐎𝐔𝐍𝐓
Special offer for today only {{DATE}}

HONEY BUNDLES:
❌(̶b̶e̶f̶o̶r̶e̶:̶ ̶P̶999)̶❌
Set A: 𝟏 𝐋𝐢𝐭𝐞𝐫 𝐇𝐨𝐧𝐞𝐲✅₱𝟕𝟒𝟗𝒐𝒏𝒍𝒚 ( 𝟔𝟒𝟗 + 100 Shipping Fee)
Set B : 𝟑 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲✅₱𝟏,6𝟗𝟗 𝒐𝒏𝒍𝒚 originally ₱̶1̶7̶9̶9̶ (FREE SHIPPING)‼️𝑩𝑬𝑺𝑻 𝑺𝑬𝑳𝑳𝑬𝑹 🔖
Set C : 𝟐 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲✅₱𝟏,𝟐𝟗𝟗 𝒐𝒏𝒍𝒚 (FREE SHIPPING)
Set D: 1 Gallon Honey✅₱1,999 𝒐𝒏𝒍𝒚 (FREE SHIPPING)

Also Available  𝗕𝗟𝗔𝗖𝗞 𝗥𝗜𝗖𝗘 𝗖𝗢𝗙𝗙𝗘𝗘 (100g) and 𝗣𝗔𝗥𝗔𝗚𝗜𝗦 𝗧𝗘𝗔 (50g) Bundle:
 Bundle A: 𝟏 𝐋𝐢𝐭𝐞𝐫 𝐇𝐨𝐧𝐞𝐲 with 𝟏 𝐂𝐨𝐟𝐟𝐞𝐞 or 𝟏 𝐏𝐚𝐫𝐚𝐠𝐢𝐬 𝐓𝐞𝐚  ✅
₱𝟗𝟗𝟗
 Bundle B: 𝟐 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲 with 1 Coffee or Paragis Tea  ✅
₱𝟏,𝟒𝟗𝟗
 Bundle  C : 𝟑 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲 with 1 Coffee or Paragis Tea  ✅
₱𝟏,𝟗𝟗𝟗

OR pair your HONEY with our 𝐅𝐈𝐍𝐄𝐒𝐓 𝐂𝐀𝐂𝐀𝐎 𝐓𝐀𝐁𝐋𝐄𝐓𝐒 220g
 Promo A: 𝟏 𝐋𝐢𝐭𝐞𝐫 𝐇𝐨𝐧𝐞𝐲 with 𝟏 𝐣𝐚𝐫 𝐏𝐫𝐞𝐦𝐢𝐮𝐦 𝐓𝐚𝐛𝐥𝐞𝐲𝐚 ✅
₱𝟏,𝟎𝟗𝟗
 Promo B: 𝟐 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲 with 𝟏 𝐣𝐚𝐫 𝐏𝐫𝐞𝐦𝐢𝐮𝐦 𝐓𝐚𝐛𝐥𝐞𝐲𝐚 ✅
₱𝟏,𝟔𝟒𝟗
 Promo  C : 𝟑 𝐋𝐢𝐭𝐞𝐫𝐬 𝐇𝐨𝐧𝐞𝐲 with 𝟏 𝐣𝐚𝐫 𝐏𝐫𝐞𝐦𝐢𝐮𝐦 𝐓𝐚𝐛𝐥𝐞𝐲𝐚 ✅
₱𝟐,𝟏𝟒𝟗
''';

const _hmCacao = '''
⚡🔥𝐅𝐋𝐀𝐒𝐇 𝐒𝐀𝐋𝐄 𝐓𝐇𝐈𝐒 𝟐𝟒 𝐇𝐎𝐔𝐑𝐒 𝐎𝐍𝐋𝐘🔥⚡
𝐓𝐎𝐃𝐀𝐘: {{DATE}}
🎯‼️💰SAVE AS MUCH AS 2,100 pesos🎯‼️💰
✅𝗡𝗢𝗪✅
🔥✅ Buy 1 Jar Cacao Tablets Only = P799
🔥✅ Buy 2 Jars Cacao Tablets Only = P1399
🔥✅ Buy 3  Jars + 1 FREE Jar Cacao Tablets Only with 6 FREEBIES = P1799 (BEST BUY)

ALSO AVAILABLE: HONEY BUNDLES
🔥✅ Buy 1 Jar Cacao Tablets w/ 200ml Honey = P999
🔥✅ Buy 1 Take 1 Jar Cacao Tablets w/ 200ml Honey = P1,599
🔥✅ Buy 3 Take 1 Jar Cacao Tablets w/ 200ml Honey+ 6 Freebies = P1,999🍫
20-26 TABLETS EACH JAR
''';

const _hmBlackRice = '''
1 Pouch BLACK RICE COFFEE - ₱499.00
2 Pouch BLACK RICE COFFEE - ₱799.00
3 Pouch BLACK RICE COFFEE - ₱899.00
''';

const _delivery = '''
Usually estimated shipping time po if
Luzon area: 8-10 days
Visayas area: 5-7 days
Mindanao area: 3-5 days Depende po if walang delay during in transit. J&T EXPRESS po ang courier namin 🙂
minsan mas early pa po sa estimated shipping time.
''';

const _benefitsHoney = '''
Marami na pong proven health benefits ang wild honey kaya mainam ito na alternative sa sugar for regular consumption. You can also use honey as food preservative and Skin care.
✅ GOOD SOURCE OF ANTIOXIDANTS
✅ ANTIBACTERIAL PROPERTIES
✅ HEAL WOUNDS
✅ PHYTONUTRIENT POWERHOUSE
✅ HELPS DIGESTIVE ISSUES
✅ SOOTHE A SORE THROAT
✅ AID FOR WEIGHTLOSS
✅ PREVENT CANCER, HEART DISEASE, DIABETES and many more…
''';

const _benefitsParagis = '''
𝐏𝐫𝐞𝐦𝐢𝐮𝐦 𝐏𝐚𝐫𝐚𝐠𝐢𝐬 𝐓𝐞𝐚 𝐛𝐲 𝐏𝐘𝐗 𝐅𝐨𝐨𝐝 𝐏𝐫𝐨𝐝𝐮𝐜𝐭𝐬
✅ Helps with constipation
✅ For Internal body Cleansing, Detox & colon Cleansing
✅ Immune System Booster
✅ Lowers Cholesterol & good for the heart, liver & Kidneys
✅ Has anti cancer properties
✅ Helps you to get 𝐩𝐫𝐞𝐠𝐧𝐚𝐧𝐭
✅ Normalizing irregular 𝐦𝐞𝐧𝐬𝐭𝐫𝐮𝐚𝐭𝐢𝐨𝐧
✅ Producing healthy 𝐞𝐠𝐠/𝐬𝐩𝐞𝐫𝐦 𝐜𝐞𝐥𝐥𝐬
✅ Helps increase 𝐬𝐩𝐞𝐫𝐦 𝐜𝐨𝐮𝐧𝐭
✅ Good for those with 𝐏𝐂𝐎𝐒 𝐚𝐧𝐝 𝐌𝐲𝐨𝐦𝐚
✅ Prevents excessive bleeding & 𝐝𝐲𝐬𝐦𝐞𝐧𝐨𝐫𝐫𝐡𝐞𝐚/ 𝐦𝐞𝐧𝐬𝐭𝐫𝐮𝐚𝐭𝐢𝐨𝐧 𝐜𝐫𝐚𝐦𝐩𝐬
''';

const _benefitsCacao = '''
Heart Protection: Rich in flavonoids that help relax your blood vessels, improve blood circulation, and lower blood pressure.High Antioxidants: Packed with polyphenols that combat oxidative stress and lower chronic inflammation in the body.
Essential Minerals: Provides a natural source of iron, potassium, and magnesium to support nerve function, muscle health, and daily energy levels.
Mood Enhancement: Contains theobromine and phenylethylamine, natural compounds that boost alertness, reduce stress, and lift your spirits.
Pure and Unprocessed: Retains more nutrients than heavily refined cocoa powders because it keeps the natural cacao fats and solids intact.
''';

const _benefitsBlackRice = '''
Why Choose 𝐅𝐢𝐧𝐞𝐬𝐭 𝐁𝐥𝐚𝐜𝐤 𝐑𝐢𝐜𝐞 𝐂𝐨𝐟𝐟𝐞𝐞 𝐰𝐢𝐭𝐡 𝐌𝐚𝐧𝐠𝐨𝐬𝐭𝐞𝐞𝐧 𝐛𝐲 𝐏𝐘𝐗 𝐅𝐨𝐨𝐝 𝐏𝐫𝐨𝐝𝐮𝐜𝐭𝐬 ?
✅ Richer Proteins
✅ Boost heart health
✅ Supports eye health
✅ Good Source of Fiber
✅ Anti Depressant
✅ Promotes a healthy immune system
''';

const _fda = '''
Here is our fda certification po you can check us sa fda site. You may click the link below.

https://www.fda.gov.ph/?s=pyx+food+products
''';

const _delivered = '''
Order has been successfully delivered. Maraming salamat po sa pag tangkilik nag ating local products. Sa uulitin po! 🙂

PS: We'd like to hear from you 🙂 We hope you find time to send us your proof of order and feedback. 🙂

Thank you! Stay Safe and BEE healthy :).
''';
