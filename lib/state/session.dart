import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/person.dart';

/// Someone you vibed with and saved. The quiet "meeting people" layer — never
/// called dating, but this is the seed of it. Mutual sparks are the payoff.
class Spark {
  Spark({required this.name, required this.hue, required this.mutual, required this.vibe, this.liveNow = false});
  final String name;
  final double hue;
  bool mutual;
  final String vibe;
  bool liveNow;
}

/// A captured moment — the reveal beat, saved. The unit of the growth loop:
/// each one becomes a shareable card built to spread.
class Moment {
  Moment({required this.game, required this.result, required this.hues, required this.laughs, required this.ago});
  final String game;
  final String result;
  final List<double> hues; // participant glows
  final int laughs;
  final String ago;
}

/// App-wide state: identity, funny stats, sparks, moments, live count, and the
/// short memory that keeps games unpredictable.
class AppSession extends ChangeNotifier {
  AppSession._() {
    _initIdentity();
    _seedSparks();
    _seedMoments();
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
  late String myUid; // stable id sent to the backend

  /// The vibes picked in onboarding — shapes matchmaking + game selection later.
  List<String> myVibes = [];
  static const _handleWords = [
    'wildcard', 'menace', 'ghost', 'goblin', 'sunny', 'chaos', 'riot',
    'maple', 'nova', 'zephyr', 'biscuit', 'vortex', 'gremlin', 'echo',
  ];
  void _initIdentity() {
    myHandle = '${_handleWords[_r.nextInt(_handleWords.length)]}${10 + _r.nextInt(89)}';
    myHue = const <double>[205, 212, 196, 220, 190, 208, 216, 200][_r.nextInt(8)];
    myUid = List.generate(20, (_) => _r.nextInt(16).toRadixString(16)).join();
  }

  // ---- persistence (so a cold start skips onboarding) ----------------------
  SharedPreferences? _prefs;
  bool onboarded = false;

  /// Load saved identity + onboarding state. Call once at launch *before* the
  /// network hello, so the backend sees a stable uid across sessions.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      onboarded = p.getBool('onboarded') ?? false;
      signedIn = p.getBool('signedIn') ?? false;
      myUid = p.getString('uid') ?? myUid;
      myHandle = p.getString('handle') ?? myHandle;
      myHue = p.getDouble('hue') ?? myHue;
      gender = p.getString('gender');
      lookingFor = p.getString('lookingFor');
      final a = p.getInt('age');
      if (a != null) age = a;
      myVibes = p.getStringList('vibes') ?? myVibes;
      // persist the freshly-generated identity the first time
      if (p.getString('uid') == null) await _persist();
    } catch (_) {/* first run / no store — defaults are fine */}
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool('onboarded', onboarded);
    await p.setBool('signedIn', signedIn);
    await p.setString('uid', myUid);
    await p.setString('handle', myHandle);
    await p.setDouble('hue', myHue);
    if (gender != null) await p.setString('gender', gender!);
    if (lookingFor != null) await p.setString('lookingFor', lookingFor!);
    if (age != null) await p.setInt('age', age!);
    await p.setStringList('vibes', myVibes);
  }

  /// A fresh handle suggestion (onboarding shuffle).
  String suggestHandle() =>
      '${_handleWords[_r.nextInt(_handleWords.length)]}${10 + _r.nextInt(89)}';

  void setHandle(String h) {
    final clean = h.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.length < 3) return;
    myHandle = clean.substring(0, clean.length.clamp(0, 14));
    _persist();
    notifyListeners();
  }

  /// Onboarding finished — remember it so we never show it again.
  void completeOnboarding() {
    onboarded = true;
    signedIn = true;
    _persist();
    notifyListeners();
  }

  /// A saved person and you both saved each other → mark it mutual (or add).
  void markMutual(String name, {double hue = 210}) {
    final i = sparks.indexWhere((s) => s.name == name);
    if (i >= 0) {
      sparks[i].mutual = true;
    } else {
      sparks.insert(0, Spark(name: name, hue: hue, mutual: true, vibe: 'a whole vibe', liveNow: true));
      saved.add(name);
    }
    notifyListeners();
  }

  /// A saved person just came online.
  void setSparkLive(String name, bool live) {
    final i = sparks.indexWhere((s) => s.name == name);
    if (i >= 0) {
      sparks[i].liveNow = live;
      notifyListeners();
    }
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

  // ---- badges (the room voted — you earned it) ----
  final Map<String, int> badges = {
    '😂 Funniest': 2,
    '🔥 Main Character': 1,
  };

  void earnBadge(String key) {
    badges[key] = (badges[key] ?? 0) + 1;
    chaosScore += 25;
    notifyListeners();
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

  // ---- moments (the shareable growth loop) ----
  final List<Moment> moments = <Moment>[];
  void _seedMoments() {
    moments.addAll([
      Moment(game: 'Point Party', result: 'the room pointed at @sol', hues: [212, 196, 220, 205], laughs: 31, ago: '2h'),
      Moment(game: 'Two Truths', result: 'you read them 😏 nailed the lie', hues: [205, 216], laughs: 24, ago: '5h'),
      Moment(game: 'Hot Take', result: 'the room split 68% your way', hues: [196, 220, 208], laughs: 17, ago: 'yesterday'),
      Moment(game: 'Freeze Face', result: 'you cracked 😂 @nova won', hues: [220, 208], laughs: 12, ago: 'yesterday'),
      Moment(game: 'Confession Cam', result: '4 in the room are guilty 👀', hues: [212, 190, 200, 216, 205], laughs: 42, ago: '2d'),
      Moment(game: 'Survival', result: 'the room crowned @maple', hues: [220, 196, 205], laughs: 28, ago: '2d'),
    ]);
  }

  void captureMoment({required String game, required String result, required List<double> hues}) {
    moments.insert(0, Moment(game: game, result: result, hues: hues, laughs: 3 + _r.nextInt(40), ago: 'just now'));
    while (moments.length > 40) {
      moments.removeLast();
    }
    laughs += _r.nextInt(8);
    notifyListeners();
  }

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

  void setProfile({int? age, String? gender, String? lookingFor, List<String>? vibes}) {
    if (age != null) this.age = age;
    if (gender != null) this.gender = gender;
    if (lookingFor != null) this.lookingFor = lookingFor;
    if (vibes != null) myVibes = vibes;
    _persist();
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    onboarded = false;
    age = null;
    gender = null;
    lookingFor = null;
    saved.clear();
    sparks.clear();
    _initIdentity();
    _prefs?.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _drift?.cancel();
    super.dispose();
  }
}
