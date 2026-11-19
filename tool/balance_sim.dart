// ignore_for_file: avoid_print
// Bot-Simulation zum Einstellen der Regeln.
// Aufruf: dart run tool/balance_sim.dart [Runden]
import 'dart:math';

import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/core/piece.dart';
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

/// Bewertet eine Turmoberfläche: je kleiner, desto besser. Flach und ohne
/// Löcher ist gut, einzelne tiefe Schächte sind schlecht.
double surfaceCost(List<int> h, int n) {
  var lo = 1 << 30, hi = 0;
  for (final v in h) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  var bumps = 0, wells = 0;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final v = h[y * n + x];
      var minNb = 1 << 30;
      if (x + 1 < n) bumps += (v - h[y * n + x + 1]).abs();
      if (y + 1 < n) bumps += (v - h[(y + 1) * n + x]).abs();
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final a = x + dx, b = y + dy;
        if (a < 0 || b < 0 || a >= n || b >= n) continue;
        if (h[b * n + a] < minNb) minNb = h[b * n + a];
      }
      if (minNb - v >= 2) wells += minNb - v;
    }
  }
  final spread = hi - lo;
  return bumps * 1.0 + wells * 3.0 + spread * spread * 1.5;
}

List<int> applied(List<int> h, int n, Placement p) {
  final out = [...h];
  for (final (x, y, z) in p.cells) {
    if (z + 1 > out[y * n + x]) out[y * n + x] = z + 1;
  }
  return out;
}

/// Plant den nächsten Baustein mit ein: Für die besten Ablagen des aktuellen
/// Bausteins wird die beste Antwort mit dem Vorschau-Baustein gesucht.
/// [skill] 0..1 mischt Zufall in die Bewertung (1 = fehlerfrei).
Pick lookaheadBot({double skill = 1, int width = 8}) => (s, o, rng) {
  final n = s.grid;
  final h = s.board.heights;
  final noise = (1 - skill) * 30;
  final first = <((int, int, int), List<int>, double)>[];
  for (final c in o) {
    final p = s.rules.evaluateOn(h, n, s.current, c.$1, c.$2, c.$3);
    final after = applied(h, n, p);
    final cost =
        surfaceCost(after, n) +
        (p.columns - p.supported) * 6 +
        rng.nextDouble() * (0.5 + noise);
    first.add((c, after, cost));
  }
  first.sort((a, b) => a.$3.compareTo(b.$3));
  var best = first.first.$1;
  var bestCost = double.infinity;
  for (final (c, after, cost) in first.take(width)) {
    var reply = double.infinity;
    final nx = s.next;
    for (var r = 0; r < 4; r++) {
      for (var wy = 0; wy <= n - nx.depth; wy++) {
        for (var wx = 0; wx <= n - nx.width; wx++) {
          final p = s.rules.evaluateOn(after, n, nx, wx, wy, r);
          if (!p.isValid) continue;
          final v =
              surfaceCost(applied(after, n, p), n) +
              (p.columns - p.supported) * 6;
          if (v < reply) reply = v;
        }
      }
    }
    if (reply == double.infinity) reply = 1e6; // Vorschau-Baustein passt nicht
    final total = cost * 0.5 + reply;
    if (total < bestCost) {
      bestCost = total;
      best = c;
    }
  }
  return best;
};

void run(
  String label,
  RuleConfig cfg,
  Pick bot, {
  int games = 300,
  List<PieceShape> Function(int drawn, int height)? pool,
}) {
  final pieces = <int>[], heights = <int>[], scores = <int>[];
  for (var g = 0; g < games; g++) {
    final rng = Random(g);
    final s = GameSession(rules: Rules(cfg), seed: g, pool: pool);
    while (s.phase != GamePhase.gameOver && s.piecesPlaced < 1500) {
      final o = s.rules.validPlacements(s.board, s.current);
      final (x, y, r) = bot(s, o, rng);
      s.orientation = r;
      s.wx = x;
      s.wy = y;
      s.place();
      s.finishPlacing();
    }
    pieces.add(s.piecesPlaced);
    heights.add(s.height);
    scores.add(s.score);
  }
  pieces.sort();
  heights.sort();
  num avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
  String min(int p) => (p * 3.5 / 60).toStringAsFixed(1);
  print(
    '${label.padRight(40)} Steine: Median ${pieces[games ~/ 2]}'
    ' (10%: ${pieces[games ~/ 10]}, 90%: ${pieces[games * 9 ~/ 10]})'
    '  ≈ ${min(pieces[games ~/ 2])} min'
    '  Höhe Median ${heights[games ~/ 2]}'
    '  Punkte Ø ${avg(scores).round()}',
  );
}

void main(List<String> args) {
  final games = args.isEmpty ? 100 : int.parse(args.first);
  final only = args.length > 1 ? args[1] : '';
  final variants = <(String, RuleConfig, List<PieceShape> Function(int, int)?)>[
    (
      'alt: immer 4, keine Fünfer',
      const RuleConfig(tightening: []),
      (d, _) => PieceLibrary.forProgress(d),
    ),
    ('gewählt: 10→3, Fünfer ab 20 und 30', const RuleConfig(), null),
    (
      'zum Vergleich: zusätzlich 30→2',
      const RuleConfig(tightening: [(10, 3), (30, 2)]),
      null,
    ),
  ];
  final bots = <(String, Pick)>[
    ('Zufall', randomBot),
    ('Gierig', greedyBot),
    ('Flächenbot', lookaheadBot(width: 1)),
    ('Planer', lookaheadBot()),
  ];
  for (final (name, bot) in bots) {
    if (only.isNotEmpty && !name.startsWith(only)) continue;
    for (final (label, cfg, pool) in variants) {
      run('$name · $label', cfg, bot, games: games, pool: pool);
    }
  }
}
