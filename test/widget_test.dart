import 'package:flutter_test/flutter_test.dart';
import 'package:callvault_prototype/main.dart';

void main() {
  testWidgets('Prototype screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CallVaultPrototypeApp());
    expect(find.text('CallVault Prototype'), findsOneWidget);
    expect(
      find.textContaining('Two-way call audio is not guaranteed'),
      findsOneWidget,
    );
  });
}
