import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/meta/rewards.dart';

/// Speichert den Belohnungsstand. Schlägt Laden oder Speichern fehl, gilt
/// der Stand nur für die Sitzung; das Spiel läuft weiter.
abstract interface class ProfileStore {
  Future<Profile> load();
  Future<void> save(Profile profile);
}

class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore([this._profile = const Profile()]);
  Profile _profile;

  @override
  Future<Profile> load() async => _profile;

  @override
  Future<void> save(Profile profile) async => _profile = profile;
}

/// Lokale Speicherung auf dem Gerät (offline, ohne Konto).
class LocalProfileStore implements ProfileStore {
  static const _key = 'profile_v1';

  @override
  Future<Profile> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const Profile();
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('FLIPSTACK profil: Laden fehlgeschlagen: $e');
      return const Profile();
    }
  }

  @override
  Future<void> save(Profile profile) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(profile.toJson()),
      );
    } catch (e) {
      debugPrint('FLIPSTACK profil: Speichern fehlgeschlagen: $e');
    }
  }
}

/// Hält den Belohnungsstand für Oberfläche und Spiel und speichert jede
/// Änderung sofort.
class ProfileController extends ChangeNotifier {
  ProfileController(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProfileStore store;
  final DateTime Function() _clock;
  Profile _profile = const Profile();

  /// Vor dem Laden wird nichts gespeichert, sonst würde ein leerer Stand den
  /// gespeicherten überschreiben.
  bool _loaded = false;

  Profile get profile => _profile;

  Future<void> load() async {
    final loaded = await store.load();
    _loaded = true;
    debugPrint('FLIPSTACK profil: geladen, ${loaded.coins} Münzen');
    _set(loaded.refreshed(_clock()));
  }

  /// Neuer Tag oder neue Woche: Aufgaben erneuern (z. B. beim Öffnen des Menüs).
  void refresh() {
    if (!_loaded) return;
    final p = _profile.refreshed(_clock());
    if (!identical(p, _profile)) _set(p);
  }

  RoundRewards recordRound(RoundSummary r) {
    final (p, rewards) = _profile.recordRound(r, _clock());
    _set(p);
    return rewards;
  }

  /// Zusätzliche Münzen gutschreiben (Belohnung für freiwillige Werbung).
  void addBonus(int amount) => _set(_profile.withBonus(amount));

  /// Stellt einen früheren Stand wieder her (zweite Chance: Die Abrechnung
  /// der Runde wird zurückgenommen, weil die Runde weitergeht).
  void restore(Profile p) => _set(p);

  bool buy(String id) => _try(_profile.buy(id));
  bool equip(String id) => _try(_profile.equip(id));

  bool _try(Profile? p) {
    if (p == null) return false;
    _set(p);
    return true;
  }

  void _set(Profile p) {
    _profile = p;
    if (_loaded) store.save(p);
    notifyListeners();
  }
}
