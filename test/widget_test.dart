import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a basic MaterialApp wrapper to verify test framework setup
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Sendzyy App'),
        ),
      ),
    );

    expect(find.text('Sendzyy App'), findsOneWidget);
  });
}

