import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('URL Inbox'))));
    expect(find.text('URL Inbox'), findsOneWidget);
  });
}
