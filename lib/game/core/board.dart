/// Ein belegter Rasterplatz in Plattformkoordinaten.
class Cell {
  const Cell(this.x, this.y, this.z, this.color, [this.pieceId = 0]);
  final int x, y, z;
  final int color;
  final int pieceId;
}

/// Belegung der Plattform. Alle Koordinaten sind Plattformkoordinaten und
/// ändern sich durch eine Rotation nie.
class Board {
  Board(this.n) : _heights = List.filled(n * n, 0);

  final int n;
  final List<Cell> cells = [];
  final List<int> _heights;
  final Set<int> _occupied = {};

  static int _key(int x, int y, int z) => (z * 64 + y) * 64 + x;

  /// Höhe der Säule = höchster belegter Platz + 1 (0 = leer).
  int heightAt(int x, int y) => _heights[y * n + x];

  /// Alle Säulenhöhen (Index y * n + x). Nur lesen.
  List<int> get heights => _heights;

  bool isOccupied(int x, int y, int z) => _occupied.contains(_key(x, y, z));

  int get maxHeight => _heights.reduce((a, b) => a > b ? a : b);
  int get minHeight => _heights.reduce((a, b) => a < b ? a : b);

  bool isLayerFull(int z) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!isOccupied(x, y, z)) return false;
      }
    }
    return true;
  }

  void add(Cell c) {
    assert(!isOccupied(c.x, c.y, c.z));
    cells.add(c);
    _occupied.add(_key(c.x, c.y, c.z));
    final i = c.y * n + c.x;
    if (c.z + 1 > _heights[i]) _heights[i] = c.z + 1;
  }

  /// Nimmt ganze Bausteine wieder vom Feld (zweite Chance). Nur für die
  /// zuletzt gelegten gedacht: Über ihnen liegt nichts, es bleibt also kein
  /// Stein in der Luft hängen.
  void removePieces(Set<int> pieceIds) {
    cells.removeWhere((c) => pieceIds.contains(c.pieceId));
    _occupied.clear();
    _heights.fillRange(0, _heights.length, 0);
    for (final c in cells) {
      _occupied.add(_key(c.x, c.y, c.z));
      final i = c.y * n + c.x;
      if (c.z + 1 > _heights[i]) _heights[i] = c.z + 1;
    }
  }
}
