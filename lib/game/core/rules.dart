import 'board.dart';
import 'orientation.dart';
import 'piece.dart';

/// Stellschrauben des Regelwerks.
class RuleConfig {
  const RuleConfig({
    this.grid = 5,
    this.minSupport = 0.5,
    this.maxSpread = 4,
    this.tightening = const [(10, 3)],
    this.maxHeight,
  });

  final int grid;

  /// Anteil der Würfel eines Bausteins, die beim Landen von einer
  /// aufliegenden Säule getragen werden müssen.
  final double minSupport;

  /// Grösster erlaubter Höhenunterschied am Anfang der Runde: Ein abgelegter
  /// Baustein darf höchstens so weit über die niedrigste Säule ragen
  /// ("der Turm muss gleichmässig wachsen").
  final int maxSpread;

  /// Verschärfungen als (Turmhöhe, Höhenunterschied), aufsteigend nach Höhe.
  /// Ab der genannten Turmhöhe gilt der engere Wert für neu abgelegte
  /// Bausteine. Was schon steht, bleibt gültig.
  final List<(int, int)> tightening;

  /// Optionale Obergrenze: Erreicht der Turm diese Höhe, endet die Runde als
  /// Erfolg. `null` = Endlosspiel.
  final int? maxHeight;

  /// Erlaubter Höhenunterschied bei Turmhöhe [towerHeight].
  int spreadAt(int towerHeight) {
    var s = maxSpread;
    for (final (h, v) in tightening) {
      if (towerHeight >= h && v < s) s = v;
    }
    return s;
  }
}

enum PlacementError { none, outOfBounds, unsupported, tooUneven }

/// Ergebnis der Prüfung einer Ablageposition.
class Placement {
  const Placement(
    this.error,
    this.z0,
    this.cells,
    this.supported,
    this.columns,
  );

  final PlacementError error;

  /// Höhe, auf der die unterste Ebene des Bausteins landet.
  final int z0;

  /// Zielzellen (x, y, z) in Plattformkoordinaten.
  final List<(int, int, int)> cells;

  final int supported;
  final int columns;

  bool get isValid => error == PlacementError.none;
  bool get isFullySupported => supported == columns;
}

class Rules {
  const Rules([this.config = const RuleConfig()]);

  final RuleConfig config;

  /// Prüft das Ablegen von [shape] mit Ankerzelle ([wx], [wy]) im Weltraster
  /// bei Orientierung [r]. Der Baustein fällt senkrecht, bis eine Zelle aufliegt.
  Placement evaluate(Board board, PieceShape shape, int wx, int wy, int r) =>
      evaluateOn(board.heights, board.n, shape, wx, wy, r);

  /// Wie [evaluate], aber nur auf den Säulenhöhen ([heights], Index y * n + x).
  /// Die Regeln hängen ausschliesslich von den Säulenhöhen ab.
  Placement evaluateOn(
    List<int> heights,
    int n,
    PieceShape shape,
    int wx,
    int wy,
    int r,
  ) {
    final cols = <int>[]; // Säulen des Bausteins
    final low = <int>[]; // unterste dz je Säule
    final high = <int>[]; // oberste dz je Säule
    final mapped = <(int, int, int)>[];
    for (final (dx, dy, dz) in shape.cells) {
      final x = wx + dx, y = wy + dy;
      if (x < 0 || y < 0 || x >= n || y >= n) {
        return const Placement(PlacementError.outOfBounds, 0, [], 0, 0);
      }
      final (px, py) = Orientation.worldToPlatform(x, y, r, n);
      mapped.add((px, py, dz));
      final k = py * n + px;
      final i = cols.indexOf(k);
      if (i < 0) {
        cols.add(k);
        low.add(dz);
        high.add(dz);
      } else {
        if (dz < low[i]) low[i] = dz;
        if (dz > high[i]) high[i] = dz;
      }
    }
    var z0 = 0;
    for (var i = 0; i < cols.length; i++) {
      final rest = heights[cols[i]] - low[i];
      if (rest > z0) z0 = rest;
    }
    // Auflage: Säulen, die aufliegen, und die Würfel, die sie tragen. Für die
    // Regel zählen die Würfel: Eine Säule aus zwei Würfeln, die in der Luft
    // hängt, wiegt doppelt. Bei flachen Bausteinen ist beides dasselbe.
    var supported = 0, carried = 0;
    for (var i = 0; i < cols.length; i++) {
      if (heights[cols[i]] - low[i] == z0) {
        supported++;
        carried += high[i] - low[i] + 1;
      }
    }
    final cells = [for (final (x, y, dz) in mapped) (x, y, z0 + dz)];
    var error = PlacementError.none;
    if (carried / shape.cells.length < config.minSupport) {
      error = PlacementError.unsupported;
    } else {
      // Der Baustein darf nicht zu weit über die niedrigste Säule ragen.
      var top = 0, tower = 0, lo = 1 << 30;
      for (var k = 0; k < heights.length; k++) {
        var h = heights[k];
        if (h > tower) tower = h;
        final i = cols.indexOf(k);
        if (i >= 0) {
          h = z0 + high[i] + 1;
          if (h > top) top = h;
        }
        if (h < lo) lo = h;
      }
      if (top - lo > config.spreadAt(tower)) error = PlacementError.tooUneven;
    }
    return Placement(error, z0, cells, supported, cols.length);
  }

  /// Alle gültigen Ablagen als (wx, wy, r). Leer = Spielende.
  List<(int, int, int)> validPlacements(Board board, PieceShape shape) {
    final out = <(int, int, int)>[];
    final n = board.n;
    for (var r = 0; r < 4; r++) {
      for (var wy = 0; wy <= n - shape.depth; wy++) {
        for (var wx = 0; wx <= n - shape.width; wx++) {
          if (evaluate(board, shape, wx, wy, r).isValid) out.add((wx, wy, r));
        }
      }
    }
    return out;
  }

  /// Warum [shape] nirgends passt: Anzahl der Positionen (über alle vier
  /// Orientierungen), die an zu wenig Auflage bzw. am Höhenunterschied scheitern.
  ({int unsupported, int tooUneven}) blockers(Board board, PieceShape shape) {
    var unsupported = 0, tooUneven = 0;
    final n = board.n;
    for (var r = 0; r < 4; r++) {
      for (var wy = 0; wy <= n - shape.depth; wy++) {
        for (var wx = 0; wx <= n - shape.width; wx++) {
          switch (evaluate(board, shape, wx, wy, r).error) {
            case PlacementError.unsupported:
              unsupported++;
            case PlacementError.tooUneven:
              tooUneven++;
            default:
          }
        }
      }
    }
    return (unsupported: unsupported, tooUneven: tooUneven);
  }

  bool hasAnyValidPlacement(Board board, PieceShape shape) {
    final n = board.n;
    for (var r = 0; r < 4; r++) {
      for (var wy = 0; wy <= n - shape.depth; wy++) {
        for (var wx = 0; wx <= n - shape.width; wx++) {
          if (evaluate(board, shape, wx, wy, r).isValid) return true;
        }
      }
    }
    return false;
  }
}
