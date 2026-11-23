import 'package:flutter_test/flutter_test.dart';
import 'package:kas_santri/main.dart';

void main() {
  testWidgets('App smoke test - verifies splash screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KasSantriApp());
    expect(find.text('KAS SANTRI'), findsOneWidget);
  });
}
