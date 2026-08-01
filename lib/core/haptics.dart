import 'package:flutter/services.dart';

/// Emotional haptic vocabulary for WhatIf.
///
/// Craft commandment #4: every meaningful state change gets a haptic (paired
/// with sound + visual on the same frame). We wrap Flutter's built-in
/// [HapticFeedback] in *named emotions* so call-sites read like feelings, not
/// API calls — and so we have one place to swap in Core Haptics `.ahap`
/// patterns later without touching the screens.
class Buzz {
  Buzz._();

  /// A light tick — selecting, tapping a chip, scrubbing.
  static void tick() => HapticFeedback.selectionClick();

  /// A soft confirm — a pressable actually firing.
  static void tap() => HapticFeedback.lightImpact();

  /// A committed action — lock in a vote, join a room.
  static void commit() => HapticFeedback.mediumImpact();

  /// The big one — a win, a reveal, a celebration.
  static void impact() => HapticFeedback.heavyImpact();

  /// A tension pulse used during dramatic countdowns.
  static void heartbeat() => HapticFeedback.mediumImpact();

  /// A celebratory triple-tap. Fired on the winner reveal.
  static Future<void> celebrate() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.heavyImpact();
  }
}
