import 'game_session.dart';

/// Dauerhafte Spielerstatistik (Brief Abschnitt 5, "Highscore").
class PlayerStats {
  const PlayerStats({
    this.bestScore = 0,
    this.bestHeight = 0,
    this.rounds = 0,
    this.totalScore = 0,
    this.bestCombo = 0,
    this.totalPieces = 0,
  });

  final int bestScore, bestHeight, rounds, totalScore, bestCombo, totalPieces;

  int get averageScore => rounds == 0 ? 0 : (totalScore / rounds).round();

  /// Statistik nach einer beendeten Runde.
  PlayerStats recordRound(GameSession s) => PlayerStats(
    bestScore: s.score > bestScore ? s.score : bestScore,
    bestHeight: s.height > bestHeight ? s.height : bestHeight,
    rounds: rounds + 1,
    totalScore: totalScore + s.score,
    bestCombo: s.bestCombo > bestCombo ? s.bestCombo : bestCombo,
    totalPieces: totalPieces + s.piecesPlaced,
  );

  Map<String, dynamic> toJson() => {
    'bestScore': bestScore,
    'bestHeight': bestHeight,
    'rounds': rounds,
    'totalScore': totalScore,
    'bestCombo': bestCombo,
    'totalPieces': totalPieces,
  };

  /// Fehlende oder fehlerhafte Felder zählen als 0 (robust gegen alte Stände).
  factory PlayerStats.fromJson(Map<String, dynamic> j) {
    int v(String k) => j[k] is int && (j[k] as int) >= 0 ? j[k] as int : 0;
    return PlayerStats(
      bestScore: v('bestScore'),
      bestHeight: v('bestHeight'),
      rounds: v('rounds'),
      totalScore: v('totalScore'),
      bestCombo: v('bestCombo'),
      totalPieces: v('totalPieces'),
    );
  }
}
