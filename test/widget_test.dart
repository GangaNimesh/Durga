// Basic smoke test: the app boots without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:durga/main.dart';

void main() {
  testWidgets('DurgaApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const DurgaApp());
    await tester.pump();

    // Either the login screen or the auto-login spinner should be showing —
    // either way, the widget tree built successfully.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
