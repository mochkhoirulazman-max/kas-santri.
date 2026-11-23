import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kas_santri/widgets/numpad_widget.dart';

void main() {
  testWidgets('NumpadWidget renders keys and handles taps', (WidgetTester tester) async {
    String pressed = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumpadWidget(
            onKeyPress: (k) => pressed += k,
            onBackspace: () {},
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('000'), findsOneWidget);

    await tester.tap(find.text('5'));
    expect(pressed, '5');
  });
}
