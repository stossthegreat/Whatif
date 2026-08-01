import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// App-wide state for the prototype build: the saved ("reconnect") set and a
/// living "people online" counter. In production this is the session, realtime
/// connection, and match queue.
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
