import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// WhatIf — "Black glass".
/// True black. One cool sliver of light. Huge type. Massive space.
/// Motion stays silent until it matters. The faces are the only content.
class C {
  C._();
  static const black = Color(0xFF000000);
  static const char = Color(0xFF0A0B0D);
  static const char2 = Color(0xFF141619);
  static const char3 = Color(0xFF1C1F24);

  static const glass = Color(0x0DFFFFFF); // 5% white
  static const glass2 = Color(0x14FFFFFF); // 8%
  static const hair = Color(0x17FFFFFF); // ~9%
  static const hair2 = Color(0x29FFFFFF); // ~16%
  static const spec = Color(0x73FFFFFF); // specular gloss edge (~45%)

  static const tx = Color(0xFFFFFFFF);
  static const tx2 = Color(0x9EFFFFFF); // 62%
  static const tx3 = Color(0x57FFFFFF); // 34%

  static const live = Color(0xFFFF453A); // the "you are live" red — used <5%
  static const sig = Color(0xFF9CC4FF); // the single cool signal light
  static Color sigGlow = const Color(0xFF78AFFF).withOpacity(0.55);
}

class T {
  T._();
  static const _f = null; // platform default (SF Pro / Roboto) — zero assets

  static TextStyle huge(double size) => TextStyle(
        fontFamily: _f,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -size * 0.03,
        height: 1.04,
        color: C.tx,
      );

  static const mark = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: C.tx);
  static const big = TextStyle(
      fontFamily: _f, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.08, color: C.tx);
  static const h3 = TextStyle(
      fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: C.tx);
  static const body = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.1, height: 1.4, color: C.tx2);
  static const sub = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.1, color: C.tx2);
  static const eyebrow = TextStyle(
      fontFamily: _f, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.4, color: C.tx3);
  static const tiny = TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: C.tx3);
  static const mono = TextStyle(
      fontFamily: _f, fontWeight: FontWeight.w800, color: C.tx, fontFeatures: [FontFeature.tabularFigures()]);
}

/// Motion — silence first. Springs for touch; exact curves for reveals.
class M {
  M._();
  static const quick = Duration(milliseconds: 220);
  static const base = Duration(milliseconds: 400);
  static const slow = Duration(milliseconds: 560);

  static const ease = Cubic(0.2, 0.8, 0.2, 1.0);
  static const spring = Cubic(0.34, 1.56, 0.64, 1.0);

  static const press = SpringDescription(mass: 1, stiffness: 520, damping: 20);
  static const pop = SpringDescription(mass: 1, stiffness: 340, damping: 15);
}

/// Responsive helper — the product must feel right on phone and tablet.
/// On wide screens we cap the "stage" to a comfortable column and scale up type
/// modestly, so cards never become heavy slabs.
class Responsive {
  Responsive(this.size);
  final Size size;

  double get w => size.width;
  bool get isTablet => size.shortestSide >= 600;

  /// Max width the interactive content is allowed to occupy.
  double get stageMaxWidth => isTablet ? 560 : double.infinity;

  /// Content horizontal padding.
  double get gutter => isTablet ? 40 : 24;

  /// A gentle type scale bump on large screens.
  double get scale => isTablet ? 1.12 : 1.0;

  static Responsive of(BuildContext c) => Responsive(MediaQuery.of(c).size);
}
