import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game.dart';

/// App-wide state: the saved ("reconnect") set, a living "people online" counter,
/// and the short memory that keeps the experience unpredictable (so a game never
/// plays the same way twice in a row). In production the live count comes from
/// the matchmaking server.
class AppSession extends ChangeNotifier {
  AppSession._() {
    _drift = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      final delta = (_r.nextDouble() * 10 - 3).round();
      liveCount = (liveCount + delta).clamp(8000, 99000);
      notifyListeners();
    });
  }
  static final AppSession instance = AppSession._();

  final Random _r = Random();
  Timer? _drift;

  int liveCount = 12438;
  final Set<String> saved = <String>{};

  // unpredictability memory
  GameKind? lastKind;
  final List<String> _recentHeads = [];
  Set<String> get recentHeads => _recentHeads.toSet();

  void noteCell(Cell cell) {
    lastKind = cell.game.kind;
    _recentHeads.add(cell.prompt.first);
    while (_recentHeads.length > 14) {
      _recentHeads.removeAt(0);
    }
  }

  void save(String name) {
    if (saved.add(name)) notifyListeners();
  }

  bool isSaved(String name) => saved.contains(name);

  @override
  void dispose() {
    _drift?.cancel();
    super.dispose();
  }
}
