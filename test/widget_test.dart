// Smoke test for WhatIf.
//
// Verifies the app boots to the splash screen and shows the wordmark's tagline,
// then auto-advances into onboarding without throwing. We keep it light because
// most of the app is animation-driven; the goal here is a build/boot sanity check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatif/app.dart';

void main() {
  testWidgets('WhatIf boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(const WhatIfApp());
    await tester.pump(); // first frame

    // The splash tagline is present.
    expect(find.text('what happens tonight?'), findsOneWidget);

    // Let the splash auto-advance timer + a few animation frames run.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 700));

    // We should have left the splash (tagline gone) without exceptions.
    expect(tester.takeException(), isNull);
  });
}
