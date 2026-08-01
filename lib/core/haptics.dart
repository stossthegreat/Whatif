import 'package:flutter/services.dart';

/// Precise, never buzzy. Haptics punctuate the beats: press, the countdown ramp,
/// the pop, a lock, a win.
class Buzz {
  Buzz._();

  /// Global toggle (Settings → Haptics).
  static bool enabled = true;

  static void tap() => enabled ? HapticFeedback.lightImpact() : null;
  static void tick() => enabled ? HapticFeedback.selectionClick() : null;
  static void commit() => enabled ? HapticFeedback.mediumImpact() : null;
  static void impact() => enabled ? HapticFeedback.heavyImpact() : null;

  /// A short escalating ramp used through the reveal countdown.
  static Future<void> ramp() async {
    if (!enabled) return;
    HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    HapticFeedback.mediumImpact();
  }

  /// The pop — a stranger lands.
  static Future<void> pop() async {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.lightImpact();
  }
}
