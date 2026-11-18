import 'board.dart';
import 'piece.dart';
import 'piece_bag.dart';
import 'rules.dart';

enum GamePhase { preview, placing, rotating, gameOver }

enum GameOverReason { noPlacement, summit }

/// Punkte einer Ablage, aufgeschlüsselt (transparent für die Anzeige).
class PlacementScore {
  const PlacementScore(this.base, this.layerBonus, this.layers);
  final int base, layerBonus, layers;
  int get total => base + layerBonus;
}

/// Eine Spielrunde: reiner Zustand und Regeln, ohne Darstellung und ohne Zeit.
/// Animationen meldet die Darstellung über [finishPlacing]/[finishRotating].
class GameSession {
  GameSession({Rules? rules, int? seed, List<PieceShape>? shapes})
    : rules = rules ?? const Rules(),
      _bag = PieceBag(shapes ?? PieceLibrary.prototype, seed: seed) {
    board = Board(this.rules.config.grid);
    current = _bag.next();
    next = _bag.next();
    _centerPiece();
  }

  static const pointsPerCube = 10;
  static const pointsPerLayer = 100;

  final Rules rules;
  final PieceBag _bag;
  late final Board board;

  late PieceShape current;
  late PieceShape next;

  /// Ankerzelle des aktuellen Bausteins im (kamerafesten) Weltraster.
  int wx = 0, wy = 0;

  /// Vierteldrehungen der Plattform (wächst/fällt unbegrenzt, für die Animation).
  int orientation = 0;

  GamePhase phase = GamePhase.preview;
  GameOverReason? gameOverReason;
  int score = 0;
  int piecesPlaced = 0;
  int rotations = 0;
  int _fullLayers = 0;
  int _nextPieceId = 1;

  int get height => board.maxHeight;
  int get grid => board.n;

  Placement get placement =>
      rules.evaluate(board, current, wx, wy, orientation);

  /// Verschiebt den Baustein auf die Ankerzelle (begrenzt auf das Raster).
  bool moveTo(int x, int y) {
    if (phase != GamePhase.preview && phase != GamePhase.rotating) return false;
    x = x.clamp(0, grid - current.width);
    y = y.clamp(0, grid - current.depth);
    if (x == wx && y == wy) return false;
    wx = x;
    wy = y;
    return true;
  }

  /// Dreht die Plattform um 90° ([dir] +1 = gegen, -1 = im Uhrzeigersinn, von oben gesehen).
  bool rotate(int dir) {
    if (phase != GamePhase.preview) return false;
    orientation += dir;
    rotations++;
    phase = GamePhase.rotating;
    return true;
  }

  void finishRotating() {
    if (phase == GamePhase.rotating) phase = GamePhase.preview;
  }

  /// Legt den aktuellen Baustein ab. Liefert die Ablage und die Punkte oder
  /// `null`, wenn die Position ungültig oder der Zustand falsch ist.
  (Placement, PlacementScore, int pieceId)? place() {
    if (phase != GamePhase.preview) return null;
    final p = placement;
    if (!p.isValid) return null;
    final id = _nextPieceId++;
    for (final (x, y, z) in p.cells) {
      board.add(Cell(x, y, z, current.color, id));
    }
    var layers = 0;
    while (board.isLayerFull(_fullLayers)) {
      _fullLayers++;
      layers++;
    }
    final s = PlacementScore(
      p.cells.length * pointsPerCube,
      layers * pointsPerLayer,
      layers,
    );
    score += s.total;
    piecesPlaced++;
    phase = GamePhase.placing;
    return (p, s, id);
  }

  /// Nach der Fallanimation: nächsten Baustein holen oder Runde beenden.
  void finishPlacing() {
    if (phase != GamePhase.placing) return;
    if (board.maxHeight >= rules.config.maxHeight) {
      _end(GameOverReason.summit);
      return;
    }
    current = next;
    next = _bag.next();
    _centerPiece();
    if (!rules.hasAnyValidPlacement(board, current)) {
      _end(GameOverReason.noPlacement);
    } else {
      phase = GamePhase.preview;
    }
  }

  void _end(GameOverReason r) {
    gameOverReason = r;
    phase = GamePhase.gameOver;
  }

  void _centerPiece() {
    wx = (grid - current.width) ~/ 2;
    wy = (grid - current.depth) ~/ 2;
  }
}
