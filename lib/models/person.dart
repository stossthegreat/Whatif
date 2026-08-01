import 'dart:math';
import 'package:flutter/material.dart';

/// A person in the cell. Not a fixed avatar — in the shipping product this is a
/// live video tile; in this build it's an elegant "presence" tile (a cool light
/// pooled on black) so the app runs and feels alive without a video backend.
class Person {
  Person({required this.name, required this.hue, required this.lx, required this.ly, this.id, this.uid});

  /// LiveKit participant identity in live mode (null when simulated).
  final String? id;

  /// Stable identity (survives reconnects) — the key for sparks/saves.
  final String? uid;

  /// The key sparks/saves are stored under.
  String get sparkKey => uid ?? id ?? name;
  final String name;
  final double hue; // cool range, tells people apart without breaking monochrome
  final double lx; // light pool x (0..1)
  final double ly; // light pool y (0..1)

  /// Build from a server `people` entry: {id, name, hue}.
  factory Person.fromServer(Map<String, dynamic> m, Random r) => Person(
        id: m['id'] as String?,
        uid: m['uid'] as String?,
        name: (m['name'] as String?) ?? 'someone',
        hue: ((m['hue'] as num?)?.toDouble()) ?? 210,
        lx: 0.20 + r.nextDouble() * 0.50,
        ly: 0.22 + r.nextDouble() * 0.40,
      );

  /// The pooled light color for the tile.
  Color get light => HSLColor.fromAHSL(0.34, hue, 0.45, 0.60).toColor();

  static const _names = [
    'kai', 'noor', 'remy', 'sasha', 'theo', 'luca', 'emi', 'dro',
    'wren', 'max', 'ira', 'jae', 'nova', 'sol', 'zed', 'fin', 'ash', 'juno',
  ];
  static const _hues = [205.0, 212.0, 196.0, 220.0, 190.0, 208.0, 216.0, 200.0];

  static Person random(Random r) => Person(
        name: _names[r.nextInt(_names.length)],
        hue: _hues[r.nextInt(_hues.length)],
        lx: 0.20 + r.nextDouble() * 0.50,
        ly: 0.22 + r.nextDouble() * 0.40,
      );

  /// Build a distinct group (no immediate duplicate handles).
  static List<Person> group(Random r, int n) {
    final out = <Person>[];
    final used = <String>{};
    while (out.length < n) {
      final p = random(r);
      if (used.add(p.name)) out.add(p);
    }
    return out;
  }
}
