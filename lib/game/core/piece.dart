/// Form eines Bausteins aus Einheitswürfeln, in kamerafester Ausrichtung.
/// Zellen sind (dx, dy, dz) mit dx, dy, dz >= 0. Bausteine werden nie gedreht.
class PieceShape {
  const PieceShape(this.name, this.cells, this.color);

  final String name;
  final List<(int, int, int)> cells;

  /// Farbindex im Sprite-Set.
  final int color;

  int get width => cells.fold(0, (m, c) => c.$1 > m ? c.$1 : m) + 1;
  int get depth => cells.fold(0, (m, c) => c.$2 > m ? c.$2 : m) + 1;
  int get height => cells.fold(0, (m, c) => c.$3 > m ? c.$3 : m) + 1;
}

/// Bausteine des Prototyps (Farben: 0 mint, 1 coral, 2 amber, 3 cream).
abstract final class PieceLibrary {
  static const single = PieceShape('single', [(0, 0, 0)], 3);
  static const domino = PieceShape('domino', [(0, 0, 0), (1, 0, 0)], 2);
  static const bar3 = PieceShape('bar3', [(0, 0, 0), (1, 0, 0), (2, 0, 0)], 0);
  static const corner = PieceShape('corner', [
    (0, 0, 0),
    (1, 0, 0),
    (0, 1, 0),
  ], 1);
  static const square = PieceShape('square', [
    (0, 0, 0),
    (1, 0, 0),
    (0, 1, 0),
    (1, 1, 0),
  ], 2);
  static const tee = PieceShape('tee', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (1, 1, 0),
  ], 0);

  static const prototype = [single, domino, bar3, corner, square, tee];
}
