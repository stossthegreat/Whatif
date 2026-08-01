// Smoke test: the app boots to the welcome screen without throwing.
// Most of Rivlr is camera + animation driven; this is a boot sanity check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivlr/app.dart';

void main() {
  testWidgets('Rivlr boots to welcome', (WidgetTester tester) async {
    await tester.pumpWidget(const RivlrApp());
    await tester.pump();

    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
