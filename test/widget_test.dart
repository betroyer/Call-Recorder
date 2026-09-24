import 'package:flutter_test/flutter_test.dart';
import 'package:callvault_prototype/main.dart';

void main() {
  testWidgets('App shell loads with messaging tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const CallVaultPrototypeApp());
    expect(find.text('Record'), findsWidgets);
    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Message'), findsWidgets);
    expect(find.text('Blast'), findsOneWidget);
  });
}
