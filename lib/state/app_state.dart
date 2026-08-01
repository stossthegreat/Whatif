import 'package:flutter/foundation.dart';
import '../models/identity.dart';

/// Minimal app-wide state for the prototype. No external state package — a
/// single [ChangeNotifier] the whole app can listen to. In production this is
/// where the session, real identity and realtime connection would live.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  Identity _me = Identity.guest;
  Identity get me => _me;

  bool soundOn = true;

  void updateMe(Identity id) {
    _me = id;
    notifyListeners();
  }

  void setHandle(String handle) => updateMe(_me.copyWith(handle: handle));
  void setGlyph(String glyph) => updateMe(_me.copyWith(glyph: glyph));
  void setColors(List colors) =>
      updateMe(_me.copyWith(colors: colors.cast()));
  void setVibe(String vibe) => updateMe(_me.copyWith(vibe: vibe));
}
