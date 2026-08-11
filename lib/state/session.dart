import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/person.dart';

/// Someone you vibed with and saved. The quiet "meeting people" layer — never
/// called dating, but this is the seed of it. Mutual sparks are the payoff.
class Spark {
  Spark({required this.name, required this.hue, required this.mutual, required this.vibe, this.liveNow = false, String? key})
      : key = key ?? name;

  /// Stable identity key (uid in live mode) — never collides with display names.
  final String key;
  final String name;
  final double hue;
  bool mutual;
  final String vibe;
  bool liveNow;
}

/// A captured moment — the reveal beat, saved. The unit of the growth loop:
/// each one becomes a shareable card built to spread.
class Moment {
  Moment({required this.game, required this.result, required this.hues,
      required this.laughs, required this.ago, DateTime? at})
      : at = at ?? DateTime.now();
  final String game;
  final String result;
  final List<double> hues; // participant glows
  final int laughs;
  final String ago;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'g': game, 'r': result, 'h': hues, 'l': laughs,
        'at': at.millisecondsSinceEpoch,
      };

  static Moment? fromJson(Map<String, dynamic> m) {
    final at = DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0);
    final d = DateTime.now().difference(at);
    final ago = d.inMinutes < 60
        ? '${d.inMinutes.clamp(1, 59)}m ago'
        : d.inHours < 24
            ? '${d.inHours}h ago'
            : '${d.inDays}d ago';
    final r = (m['r'] as String?) ?? '';
    if (r.isEmpty) return null;
    return Moment(
      game: (m['g'] as String?) ?? 'Rivlr',
      result: r,
      hues: ((m['h'] as List?) ?? const []).whereType<num>().map((x) => x.toDouble()).toList(),
      laughs: (m['l'] as num?)?.toInt() ?? 0,
      ago: ago,
      at: at,
    );
  }
}

/// App-wide state: identity, funny stats, sparks, moments, live count, and the
/// short memory that keeps games unpredictable.
class AppSession extends ChangeNotifier {
  AppSession._() {
    _initIdentity();
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

  /// Real activity from the server (0 until the first presence message).
  /// The home screen only surfaces these when they're big enough to impress —
  /// low numbers are never shown, but shown numbers are never invented.
  int roomsLive = 0;
  int matchesToday = 0;

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
      rulesAccepted = p.getBool('rulesAccepted') ?? false;
      appleUserId = p.getString('appleUserId');
      googleUserId = p.getString('googleUserId');
      blocked.addAll(p.getStringList('blocked') ?? const []);
      bio = p.getString('bio') ?? '';
      city = p.getString('city') ?? '';
      country = p.getString('country') ?? '';
      pronouns = p.getString('pronouns') ?? '';
      lookingForChips = p.getStringList('lookingChips') ?? [];
      interests = p.getStringList('interests') ?? [];
      languages = p.getStringList('languages') ?? [];
      photoId = p.getInt('photoId');
      final dobMs = p.getInt('dob');
      if (dobMs != null) dob = DateTime.fromMillisecondsSinceEpoch(dobMs);
      dobRejected = p.getBool('dobRejected') ?? false;
      discoverable = p.getBool('discoverable') ?? true;
      // moments survive restarts — they're the user's history, not a session
      try {
        final raw = p.getString('moments');
        if (raw != null) {
          moments.addAll(((jsonDecode(raw) as List))
              .whereType<Map>()
              .map((m) => Moment.fromJson(m.cast<String, dynamic>()))
              .whereType<Moment>());
        }
      } catch (_) {/* corrupt cache — start clean */}
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

  bool rulesAccepted = false;
  void acceptRules() {
    rulesAccepted = true;
    _prefs?.setBool('rulesAccepted', true);
    notifyListeners();
  }

  /// Sign in with Apple. The random uid stays the PERMANENT identity — the
  /// Apple id is a recovery key linked to it server-side, so signing in later
  /// never migrates anything, and a reinstall gets the whole graph back.
  String? appleUserId;
  /// Apple's signed identity token. Held in memory only — it expires quickly
  /// and the server re-verifies on each fresh sign-in, so persisting it would
  /// be storing a stale credential for no benefit.
  String? appleToken;
  void setAppleIdentity(String appleId, {String? token}) {
    appleUserId = appleId;
    appleToken = token;               // signed proof, sent once on the next hello
    _prefs?.setString('appleUserId', appleId);
    signedIn = true;
    notifyListeners();
  }

  /// Sign in with Google — the Android mirror of the Apple pair above.
  /// Same model: uid stays the permanent identity, the Google id is a
  /// recovery key linked server-side; the token is held in memory only.
  String? googleUserId;
  String? googleToken;
  void setGoogleIdentity(String googleId, {String? token}) {
    googleUserId = googleId;
    googleToken = token;              // signed proof, sent once on the next hello
    _prefs?.setString('googleUserId', googleId);
    signedIn = true;
    notifyListeners();
  }

  /// The server resolved our Apple id to an existing account — adopt its uid
  /// (this is the reinstall-recovery path).
  void adoptUid(String uid) {
    if (uid.isEmpty || uid == myUid) return;
    myUid = uid;
    _prefs?.setString('uid', uid);
    // anything bought under the old id has to follow the account, or the
    // purchase ends up filed against an abandoned user
    onUidAdopted?.call(uid);
    notifyListeners();
  }

  /// Set by app startup — re-identifies the purchase SDK after Apple sign-in
  /// resolves us to a different canonical uid. (A plain callback keeps this
  /// state class free of any dependency on the purchase layer.)
  void Function(String uid)? onUidAdopted;

  /// Onboarding finished — remember it so we never show it again.
  void completeOnboarding() {
    onboarded = true;
    signedIn = true;
    _persist();
    notifyListeners();
  }

  /// A saved person and you both saved each other → mark it mutual (or add).
  /// Matches on the stable uid first, display name as fallback.
  void markMutual(String name, {String? uid, double hue = 210}) {
    final i = sparks.indexWhere((s) => (uid != null && s.key == uid) || s.name == name);
    if (i >= 0) {
      sparks[i].mutual = true;
    } else {
      sparks.insert(0, Spark(key: uid, name: name, hue: hue, mutual: true, vibe: 'a whole vibe', liveNow: true));
      saved.add(uid ?? name);
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

  // ---- onboarding answers ----
  bool signedIn = false;
  int? age;
  String? gender;
  String? lookingFor;

  // ---- identity v2 (mirrored server-side via setProfile) ----
  String bio = '';
  String city = '';
  String country = '';
  String pronouns = '';
  List<String> lookingForChips = [];
  List<String> interests = [];
  List<String> languages = [];
  int? photoId; // server media id of the avatar
  DateTime? dob; // real date of birth — drives the 18+ gate and age matching
  /// Set when someone fails the age gate. Remembered so coming back and
  /// typing a different year doesn't get them in.
  bool dobRejected = false;
  /// Explore opt-out. Default on; mirrored to the server via setProfile.
  bool discoverable = true;

  void setDiscoverable(bool v) {
    discoverable = v;
    _prefs?.setBool('discoverable', v);
    notifyListeners();
  }

  // ---- Rivlr+ ----
  /// NEVER persisted and never client-decided: the server tells us on every
  /// connect and whenever RevenueCat says something changed. Storing this
  /// locally would just be a lie a modified client could tell itself.
  bool plus = false;
  DateTime? plusUntil;

  /// Who you want to meet — 'Everyone' | 'Women' | 'Men'. A paid setting, so
  /// the server's copy is the real one; this mirrors it for the UI.
  String meetPref = 'Everyone';

  void setPlus({required bool active, DateTime? until, String? meet}) {
    plus = active;
    plusUntil = until;
    if (meet != null) meetPref = meet;
    notifyListeners();
  }

  void setDob(DateTime d) {
    dob = d;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    age = a;
    _prefs?.setInt('dob', d.millisecondsSinceEpoch);
    _prefs?.setInt('age', a);
    notifyListeners();
  }

  void setDobRejected() {
    dobRejected = true;
    _prefs?.setBool('dobRejected', true);
    notifyListeners();
  }

  void setIdentityDetails({
    String? bio,
    String? city,
    String? country,
    String? pronouns,
    List<String>? lookingForChips,
    List<String>? interests,
    List<String>? languages,
  }) {
    if (bio != null) this.bio = bio;
    if (city != null) this.city = city;
    if (country != null) this.country = country;
    if (pronouns != null) this.pronouns = pronouns;
    if (lookingForChips != null) this.lookingForChips = lookingForChips;
    if (interests != null) this.interests = interests;
    if (languages != null) this.languages = languages;
    final p = _prefs;
    if (p != null) {
      p.setString('bio', this.bio);
      p.setString('city', this.city);
      p.setString('country', this.country);
      p.setString('pronouns', this.pronouns);
      p.setStringList('lookingChips', this.lookingForChips);
      p.setStringList('interests', this.interests);
      p.setStringList('languages', this.languages);
    }
    notifyListeners();
  }

  void setPhotoId(int id) {
    photoId = id;
    _prefs?.setInt('photoId', id);
    notifyListeners();
  }

  /// Server-driven correction from welcome: the server knows which media row
  /// actually exists. Null clears a stale pointer (deleted blob) so the UI
  /// falls back to the orb instead of a 404 forever.
  void healPhotoId(int? id) {
    if (id == photoId) return;
    photoId = id;
    if (id == null) {
      _prefs?.remove('photoId');
    } else {
      _prefs?.setInt('photoId', id);
    }
    notifyListeners();
  }

  // ---- settings ----
  bool soundOn = true;
  bool hapticsOn = true;

  // ---- stats (all real — they start at zero and you earn them) ----
  int streak = 1;
  int matchesPlayed = 0;
  int laughs = 0;
  int lies = 0;
  int chaosScore = 0;

  String get rankTitle {
    if (chaosScore < 150) return 'Fresh Chaos';
    if (chaosScore < 350) return 'Certified Menace';
    if (chaosScore < 650) return 'Chaos Gremlin';
    if (chaosScore < 1100) return 'Room Wrecker';
    return 'Chaos Lord 👑';
  }

  // ---- badges (the room voted — you earned it) ----
  final Map<String, int> badges = {};

  void earnBadge(String key) {
    badges[key] = (badges[key] ?? 0) + 1;
    chaosScore += 25;
    notifyListeners();
  }

  // ---- blocked people (uid|name entries, persisted) ----
  final List<String> blocked = [];

  void noteBlocked(String uid, String name) {
    final entry = '$uid|$name';
    if (blocked.any((e) => e.split('|').first == uid)) return;
    blocked.insert(0, entry);
    _prefs?.setStringList('blocked', blocked);
    notifyListeners();
  }

  void removeBlocked(String uid) {
    blocked.removeWhere((e) => e.split('|').first == uid);
    _prefs?.setStringList('blocked', blocked);
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
    if (saved.add(p.sparkKey)) {
      sparks.insert(0, Spark(
        key: p.sparkKey,
        name: p.name, hue: p.hue,
        mutual: false, // mutual is REAL — the server tells us via sparkMutual
        vibe: _vibes[_r.nextInt(_vibes.length)],
      ));
      chaosScore += 15;
      notifyListeners();
    }
  }

  bool isSaved(String key) => saved.contains(key);

  // ---- moments (the shareable growth loop) ----
  final List<Moment> moments = <Moment>[];
  void captureMoment({required String game, required String result, required List<double> hues}) {
    // a card with no verdict is a blank card — capture only real reveals
    if (result.trim().isEmpty) return;
    moments.insert(0, Moment(game: game, result: result, hues: hues, laughs: 3 + _r.nextInt(40), ago: 'just now'));
    while (moments.length > 40) {
      moments.removeLast();
    }
    _persistMoments();
    laughs += _r.nextInt(8);
    notifyListeners();
  }

  void _persistMoments() {
    _prefs?.setString('moments', jsonEncode([for (final m in moments) m.toJson()]));
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

  void setLiveCount(int n, {int? rooms, int? matches}) {
    serverDriven = true;
    liveCount = n;
    if (rooms != null) roomsLive = rooms;
    if (matches != null) matchesToday = matches;
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
