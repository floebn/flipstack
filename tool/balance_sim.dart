// ignore_for_file: avoid_print
// Bot-Simulation zum Einstellen der Regeln.
// Aufruf: dart run tool/balance_sim.dart
import 'dart:math';

import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/core/rules.dart';

typedef Pick = (int, int, int) Function(
  GameSession s,
  List<(int, int, int)> options,
  Random rng,
);

(int, int, int) randomBot(GameSession s, List<(int, int, int)> o, Random rng) =>
    o[rng.nextInt(o.length)];

/// Legt möglichst tief und möglichst vollständig gestützt ab.
(int, int, int) greedyBot(GameSession s, List<(int, int, int)> o, Random rng) {
  (int, int, int)? best;
  var bestScore = 1 << 30;
  for (final c in o) {
    final p = s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3);
    final cost = p.z0 * 10 + (p.columns - p.supported) * 25 + rng.nextInt(3);
    if (cost < bestScore) {
      bestScore = cost;
      best = c;
    }
  }
  return best!;
}

void run(String label, RuleConfig cfg, Pick bot, {int games = 300}) {
  final pieces = <int>[], heights = <int>[], scores = <int>[];
  var summits = 0;
  for (var g = 0; g < games; g++) {
    final rng = Random(g);
    final s = GameSession(rules: Rules(cfg), seed: g);
    while (s.phase != GamePhase.gameOver && s.piecesPlaced < 2000) {
      final o = s.rules.validPlacements(s.board, s.current);
      final (x, y, r) = bot(s, o, rng);
      s.orientation = r;
      s.wx = x;
      s.wy = y;
      s.place();
      s.finishPlacing();
    }
    if (s.gameOverReason == GameOverReason.summit) summits++;
    pieces.add(s.piecesPlaced);
    heights.add(s.height);
    scores.add(s.score);
  }
  pieces.sort();
  num avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
  print(
    '${label.padRight(34)} Steine: Median ${pieces[games ~/ 2]}'
    ' (10%: ${pieces[games ~/ 10]}, 90%: ${pieces[games * 9 ~/ 10]})'
    '  Höhe Ø ${avg(heights).toStringAsFixed(1)}'
    '  Punkte Ø ${avg(scores).round()}'
    '  Gipfel ${(100 * summits / games).round()}%',
  );
}

void main() {
  for (final (support, spread) in [
    (0.5, 4),
    (0.5, 3),
    (0.5, 2),
    (1.0, 4),
    (1.0, 3),
    (1.0, 2),
    (0.75, 3),
  ]) {
    final cfg = RuleConfig(minSupport: support, maxSpread: spread);
    run('Zufall  support=$support spread=$spread', cfg, randomBot);
    run('Gierig  support=$support spread=$spread', cfg, greedyBot);
  }
}
