import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/person.dart';

/// Someone you vibed with and saved. The quiet "meeting people" layer — never
/// called dating, but this is the seed of it. Mutual sparks are the payoff.
class Spark {
  Spark({required this.name, required this.hue, required this.mutual, required this.vibe, this.liveNow = false});
  final String name;
  final double hue;
  final bool mutual;
  final String vibe;
  bool liveNow;
}

/// App-wide state: identity, funny stats, sparks, live count, and the short
/// memory that keeps games unpredictable.
class AppSession extends ChangeNotifier {
  AppSession._() {
    _initIdentity();
    _seedSparks();
    _drift = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (serverDriven) return;
      liveCount = (liveCount + (_r.nextDouble() * 10 - 3).round()).clamp(8000, 99000);
      notifyListeners();
    });
  }
  static final AppSession instance = AppSession._();

  final Random _r = Random();
  Timer? _drift;

  int liveCount = 12438;
  bool serverDriven = false;

  // ---- your identity (anonymous, fun) ----
  late String myHandle;
  late double myHue;
  static const _handleWords = [
    'wildcard', 'menace', 'ghost', 'goblin', 'sunny', 'chaos', 'riot',
    'maple', 'nova', 'zephyr', 'biscuit', 'vortex', 'gremlin', 'echo',
  ];
  void _initIdentity() {
    myHandle = '${_handleWords[_r.nextInt(_handleWords.length)]}${10 + _r.nextInt(89)}';
    myHue = const [205.0, 212, 196, 220, 190, 208, 216, 200][_r.nextInt(8)];
  }

  void _seedSparks() {
    sparks.addAll([
      Spark(name: 'nova', hue: 212, mutual: true, vibe: 'a whole vibe', liveNow: true),
      Spark(name: 'ghost', hue: 196, mutual: false, vibe: 'unhinged'),
      Spark(name: 'maple', hue: 220, mutual: true, vibe: 'so real'),
    ]);
    saved.addAll(['nova', 'ghost', 'maple']);
  }

  // ---- onboarding answers ----
  bool signedIn = false;
  int? age;
  String? gender;
  String? lookingFor;

  // ---- settings ----
  bool soundOn = true;
  bool hapticsOn = true;

  // ---- funny stats ----
  int streak = 3;
  int matchesPlayed = 27;
  int laughs = 118;
  int lies = 9;
  int chaosScore = 340;

  String get rankTitle {
    if (chaosScore < 150) return 'Fresh Chaos';
    if (chaosScore < 350) return 'Certified Menace';
    if (chaosScore < 650) return 'Chaos Gremlin';
    if (chaosScore < 1100) return 'Room Wrecker';
    return 'Chaos Lord 👑';
  }

  // ---- sparks (people you vibed with) ----
  final Set<String> saved = <String>{};
  final List<Spark> sparks = <Spark>[];
  static const _vibes = [
    'chaotic', 'hilarious', 'actually deep', 'a menace', 'so real', 'unhinged', 'a whole vibe', 'dangerous',
  ];
  int get mutualCount => sparks.where((s) => s.mutual).length;

  void spark(Person p) {
    if (saved.add(p.name)) {
      sparks.insert(0, Spark(
        name: p.name, hue: p.hue,
        mutual: _r.nextDouble() < 0.45,
        vibe: _vibes[_r.nextInt(_vibes.length)],
        liveNow: _r.nextBool(),
      ));
      chaosScore += 15;
      notifyListeners();
    }
  }

  bool isSaved(String name) => saved.contains(name);

  // ---- unpredictability memory ----
  GameKind? lastKind;
  final List<String> _recentHeads = [];
  Set<String> get recentHeads => _recentHeads.toSet();

  void noteCell(Cell cell) {
    lastKind = cell.game.kind;
    _recentHeads.add(cell.prompt.first);
    while (_recentHeads.length > 14) {
      _recentHeads.removeAt(0);
    }
    matchesPlayed++;
    chaosScore += 5 + _r.nextInt(18);
    laughs += _r.nextInt(6);
    notifyListeners();
  }

  void setLiveCount(int n) {
    serverDriven = true;
    liveCount = n;
    notifyListeners();
  }

  void setProfile({int? age, String? gender, String? lookingFor}) {
    if (age != null) this.age = age;
    if (gender != null) this.gender = gender;
    if (lookingFor != null) this.lookingFor = lookingFor;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    age = null;
    gender = null;
    lookingFor = null;
    saved.clear();
    sparks.clear();
    _initIdentity();
    notifyListeners();
  }

  @override
  void dispose() {
    _drift?.cancel();
    super.dispose();
  }
}
