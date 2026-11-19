import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../game/core/player_stats.dart';

/// Speichert die Spielerstatistik. Das Spiel funktioniert auch, wenn Laden
/// oder Speichern fehlschlägt (dann gilt die Statistik nur für die Sitzung).
abstract interface class StatsStore {
  Future<PlayerStats> load();
  Future<void> save(PlayerStats stats);
}

class MemoryStatsStore implements StatsStore {
  PlayerStats _stats = const PlayerStats();

  @override
  Future<PlayerStats> load() async => _stats;

  @override
  Future<void> save(PlayerStats stats) async => _stats = stats;
}

/// Lokale Speicherung auf dem Gerät (offline, ohne Konto).
class LocalStatsStore implements StatsStore {
  static const _key = 'player_stats_v1';

  @override
  Future<PlayerStats> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const PlayerStats();
      return PlayerStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerStats();
    }
  }

  @override
  Future<void> save(PlayerStats stats) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(stats.toJson()),
      );
    } catch (_) {
      // Speichern ist nicht spielentscheidend; die Runde läuft weiter.
    }
  }
}
