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
  Pick bot, {
  int games = 100,
  DifficultyCurve curve = const DifficultyCurve(),
  RuleConfig cfg = const RuleConfig(),
}) {
  final pieces = <int>[], heights = <int>[];
  for (var g = 0; g < games; g++) {
    final rng = Random(g);
    final s = GameSession(rules: Rules(cfg), seed: g, curve: curve);
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
  }
  pieces.sort();
  heights.sort();
  int q(List<int> l, double f) =>
      l[(l.length * f).floor().clamp(0, l.length - 1)];
  String min(int p) => (p * 3.5 / 60).toStringAsFixed(1).padLeft(5);
  final over60 = heights.where((h) => h >= 60).length * 100 ~/ games;
  int pct(int h) => heights.where((x) => x >= h).length * 100 ~/ games;
  final capped = pieces.where((p) => p >= 1500).length;
  print(
    '${label.padRight(34)}'
    ' Höhe 10%/50%/90%: ${q(heights, .1).toString().padLeft(3)} /'
    ' ${q(heights, .5).toString().padLeft(3)} / ${q(heights, .9).toString().padLeft(3)}'
    '   Steine Median ${q(pieces, .5).toString().padLeft(4)}'
    '   ≈${min(q(pieces, .5))} min'
    '   ≥60: ${over60.toString().padLeft(2)} %  ≥80: ${pct(80).toString().padLeft(2)} %'
    '  ≥100: ${pct(100).toString().padLeft(2)} %  höchste ${heights.last}'
    '${capped > 0 ? '  ($capped Runden bei 1500 Steinen abgebrochen)' : ''}',
  );
}

/// Aufruf: dart run tool/balance_sim.dart [Runden] [Bot-Anfang] [Variante]
void main(List<String> args) {
  final games = args.isEmpty ? 100 : int.parse(args.first);
  final onlyBot = args.length > 1 ? args[1] : '';
  final onlyVar = args.length > 2 ? args[2] : '';
  const never = 1 << 20;
  final variants = <(String, DifficultyCurve)>[
    (
      'A alt: Fünfer 20/30, danach nichts',
      const DifficultyCurve(
        fivers1: 20,
        fivers2: 30,
        noSingle: never,
        noDomino: never,
        doubleFivers: never,
        dropFrom: never,
      ),
    ),
    (
      'B nur Fünfer früher (15/25)',
      const DifficultyCurve(
        noSingle: never,
        noDomino: never,
        doubleFivers: never,
        dropFrom: never,
      ),
    ),
    (
      'C erster Vorschlag (40/50/60/70+)',
      const DifficultyCurve(
        noSingle: 40,
        noDomino: 50,
        doubleFivers: 60,
        dropFrom: 70,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'D strenger (30/40/50/60+)',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 50,
        dropFrom: 60,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    ('F gewählt (30/35/40, dann alle 5 ab 45)', const DifficultyCurve()),
    (
      'G Fünfer 10/20, dann 30/40/50/60+',
      const DifficultyCurve(
        fivers1: 10,
        fivers2: 20,
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 50,
        dropFrom: 60,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'H Fünfer doppelt früh (30/40/35/50+)',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 35,
        dropFrom: 50,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'M1 30/40/50, weg ab 60 alle 10',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 50,
        dropFrom: 60,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'M2 30/35/45, weg ab 55 alle 10',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 35,
        doubleFivers: 45,
        dropFrom: 55,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'M3 30/40/45, weg ab 55 alle 10',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 45,
        dropFrom: 55,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
    (
      'M4 30/40/50, weg ab 55 alle 5',
      const DifficultyCurve(
        noSingle: 30,
        noDomino: 40,
        doubleFivers: 50,
        dropFrom: 55,
        dropEvery: 5,
        maxLateDrops: 4,
      ),
    ),
    ('N gewählt: 30/35/45/55, ab 60 nichts mehr', const DifficultyCurve()),
    (
      'E milder (50/60/70/80+)',
      const DifficultyCurve(
        noSingle: 50,
        noDomino: 60,
        doubleFivers: 70,
        dropFrom: 80,
        dropEvery: 10,
        maxLateDrops: 4,
      ),
    ),
  ];
  // Die Bots mit "Fehlern" mischen Zufall in die Bewertung und stehen für
  // Menschen, die nicht jede Lage optimal lösen.
  final bots = <(String, Pick)>[
    ('Gierig', greedyBot),
    ('Fläche mit vielen Fehlern', lookaheadBot(width: 1, skill: 0.55)),
    ('Fläche mit Fehlern', lookaheadBot(width: 1, skill: 0.8)),
    ('Fläche fehlerfrei', lookaheadBot(width: 1)),
    ('Planer fehlerfrei', lookaheadBot()),
  ];
  for (final (name, bot) in bots) {
    if (onlyBot.isNotEmpty && !name.startsWith(onlyBot)) continue;
    print(name);
    for (final (label, curve) in variants) {
      if (onlyVar.isNotEmpty && !label.startsWith(onlyVar)) continue;
      run('  $label', bot, games: games, curve: curve);
    }
  }
}
