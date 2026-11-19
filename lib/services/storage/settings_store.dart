import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Einstellungen des Spielers. Änderungen werden sofort lokal gespeichert;
/// schlägt das fehl, gelten sie für die laufende Sitzung.
class Settings extends ChangeNotifier {
  bool _sound = true;
  bool _haptics = true;
  bool _tutorialDone = false;

  bool get sound => _sound;
  bool get haptics => _haptics;
  bool get tutorialDone => _tutorialDone;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _sound = p.getBool('sound') ?? true;
      _haptics = p.getBool('haptics') ?? true;
      _tutorialDone = p.getBool('tutorialDone') ?? false;
    } catch (_) {}
    notifyListeners();
  }

  set sound(bool v) => _set('sound', () => _sound = v);
  set haptics(bool v) => _set('haptics', () => _haptics = v);
  set tutorialDone(bool v) => _set('tutorialDone', () => _tutorialDone = v);

  void _set(String key, bool Function() apply) {
    final v = apply();
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool(key, v))
        .catchError((_) => false);
  }
}
