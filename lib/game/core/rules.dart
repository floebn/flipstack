import 'board.dart';
import 'orientation.dart';
import 'piece.dart';

/// Stellschrauben des Regelwerks.
class RuleConfig {
  const RuleConfig({
    this.grid = 5,
    this.minSupport = 0.5,
    this.maxSpread = 4,
    this.maxHeight = 30,
  });

  final int grid;

  /// Anteil der Säulen eines Bausteins, die beim Landen aufliegen müssen.
  final double minSupport;

  /// Grösster erlaubter Höhenunterschied zwischen höchster und niedrigster
  /// Säule nach dem Ablegen ("der Turm muss gleichmässig wachsen").
  final int maxSpread;

  /// Erreicht der Turm diese Höhe, endet die Runde als Erfolg.
  final int maxHeight;
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
  Placement evaluate(Board board, PieceShape shape, int wx, int wy, int r) {
    final n = board.n;
    final lowest = <int, int>{}; // Säule -> unterste dz des Bausteins
    final mapped = <(int, int, int)>[];
    for (final (dx, dy, dz) in shape.cells) {
      final x = wx + dx, y = wy + dy;
      if (x < 0 || y < 0 || x >= n || y >= n) {
        return const Placement(PlacementError.outOfBounds, 0, [], 0, 0);
      }
      final (px, py) = Orientation.worldToPlatform(x, y, r, n);
      mapped.add((px, py, dz));
      final k = py * n + px;
      final cur = lowest[k];
      if (cur == null || dz < cur) lowest[k] = dz;
    }
    var z0 = 0;
    lowest.forEach((k, dz) {
      final rest = board.heightAt(k % n, k ~/ n) - dz;
      if (rest > z0) z0 = rest;
    });
    var supported = 0;
    lowest.forEach((k, dz) {
      if (board.heightAt(k % n, k ~/ n) - dz == z0) supported++;
    });
    final cells = [for (final (x, y, dz) in mapped) (x, y, z0 + dz)];
    var error = PlacementError.none;
    if (supported / lowest.length < config.minSupport) {
      error = PlacementError.unsupported;
    } else {
      // Höhenunterschied nach dem Ablegen
      final top = <int, int>{};
      for (final (x, y, z) in cells) {
        final k = y * n + x;
        if (z + 1 > (top[k] ?? 0)) top[k] = z + 1;
      }
      var lo = 1 << 30, hi = 0;
      for (var k = 0; k < n * n; k++) {
        final h = top[k] ?? board.heightAt(k % n, k ~/ n);
        if (h < lo) lo = h;
        if (h > hi) hi = h;
      }
      if (hi - lo > config.maxSpread) error = PlacementError.tooUneven;
    }
    return Placement(error, z0, cells, supported, lowest.length);
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
