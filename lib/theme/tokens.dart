import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Rivlr — "Noir neon".
/// Black canvas, violet-tinted glass, one electric purple, one acid spark.
/// Huge condensed display type. Motion stays silent until it matters.
/// The faces are the only content — everything else is stage lighting.
class C {
  C._();
  static const black = Color(0xFF000000);
  static const char = Color(0xFF0A0714); // violet-black
  static const char2 = Color(0xFF130E1E);
  static const char3 = Color(0xFF1B1428);

  static const glass = Color(0x0DFFFFFF); // 5% white
  static const glass2 = Color(0x14FFFFFF); // 8%
  static const hair = Color(0x17FFFFFF); // ~9%
  static const hair2 = Color(0x29FFFFFF); // ~16%
  static const spec = Color(0x73FFFFFF); // specular gloss edge (~45%)

  static const tx = Color(0xFFFFFFFF);
  static const tx2 = Color(0x9EFFFFFF); // 62%
  static const tx3 = Color(0x57FFFFFF); // 34%

  static const live = Color(0xFFFF3B5C); // the "you are live" / danger red
  static const sig = Color(0xFFA36BFF); // the signature purple accent
  static Color sigGlow = const Color(0xFF8B3DFF).withOpacity(0.6);
  static const blue = Color(0xFF4DA6FF); // rare secondary glow (occasional)
  static const purpleDeep = Color(0xFF6D28D9);

  /// The acid spark — reserved for LIFE: online dots, live counts, "free
  /// now", unread badges. Never decoration; if it's acid, someone is there.
  static const acid = Color(0xFFC8FF3D);
  static const acidGlow = Color(0x80C8FF3D);

  /// The primary action language — every key button wears this.
  static const gradSig = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [sig, purpleDeep]);

  /// Hotter variant for the single hero moment on a screen.
  static const gradSigHot = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC084FF), sig, purpleDeep]);

  static List<BoxShadow> glowSig({double blur = 22, double spread = -6}) =>
      [BoxShadow(color: sigGlow, blurRadius: blur, spreadRadius: spread)];
}

/// Radius vocabulary — new/touched surfaces speak these four words.
class R {
  R._();
  static const card = 24.0;
  static const chip = 100.0;
  static const sheet = 26.0;
  static const btn = 18.0;
}

class T {
  T._();
  static const _f = null; // body voice: platform default (SF Pro / Roboto)

  /// The brand voice — Anton, tall condensed caps. Headers, wordmark, big
  /// numbers, names on cards. Single weight: w400 always (anything bolder
  /// fakes it). Write literals ALREADY UPPERCASE; `.toUpperCase()` only on
  /// dynamic strings.
  static TextStyle display(double size) => TextStyle(
        fontFamily: 'Anton',
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: size * 0.02,
        height: 1.02,
        color: C.tx,
      );

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
