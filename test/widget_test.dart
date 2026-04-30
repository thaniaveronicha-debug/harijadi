import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birthday/main.dart';

void main() {
  testWidgets('Birthday App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BirthdayApp());

    // Verify that we start with the empty state message.
    expect(find.textContaining('Tiada rekod'), findsOneWidget);

    // Verify that the add button is present.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
