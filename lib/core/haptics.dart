import 'package:flutter/services.dart';

/// Precise, never buzzy. Haptics punctuate the beats: press, the countdown ramp,
/// the pop, a lock, a win.
class Buzz {
  Buzz._();
  static void tap() => HapticFeedback.lightImpact();
  static void tick() => HapticFeedback.selectionClick();
  static void commit() => HapticFeedback.mediumImpact();
  static void impact() => HapticFeedback.heavyImpact();

  /// A short escalating ramp used through the reveal countdown.
  static Future<void> ramp() async {
    HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    HapticFeedback.mediumImpact();
  }

  /// The pop — a stranger lands.
  static Future<void> pop() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.lightImpact();
  }
}
