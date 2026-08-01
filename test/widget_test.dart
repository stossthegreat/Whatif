// Smoke test: the app boots to onboarding without throwing.
// Most of WhatIf is camera + animation driven; this is a boot sanity check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatif/app.dart';

void main() {
  testWidgets('WhatIf boots to onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const WhatIfApp());
    await tester.pump();

    // The first-run headline is present and no exception was thrown.
    expect(find.textContaining('Right now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
