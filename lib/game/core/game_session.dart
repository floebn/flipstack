import 'board.dart';
import 'piece.dart';
import 'piece_bag.dart';
import 'rules.dart';

enum GamePhase { preview, placing, rotating, gameOver }

enum GameOverReason { noPlacement, summit }

/// Woran der letzte Baustein gescheitert ist.
enum BlockCause { tooUneven, unsupported, both }

/// Punkte einer Ablage, aufgeschlüsselt (transparent für die Anzeige).
class PlacementScore {
  const PlacementScore({
    required this.base,
    required this.cleanBonus,
    required this.multiplier,
    required this.combo,
    required this.layers,
    required this.layerBonus,
    required this.milestones,
    required this.milestoneBonus,
  });

  /// 10 Punkte je Würfel.
  final int base;

  /// +50 %, wenn der Baustein vollständig aufliegt.
  final int cleanBonus;

  /// Combo-Multiplikator auf [base] + [cleanBonus].
  final double multiplier;

  /// Anzahl sauberer Ablagen in Folge (0 = Serie beendet).
  final int combo;
  final int layers, layerBonus;
  final int milestones, milestoneBonus;

  bool get clean => cleanBonus > 0;
  int get placement => ((base + cleanBonus) * multiplier).round();
  int get total => placement + layerBonus + milestoneBonus;
}

/// Eine Spielrunde: reiner Zustand und Regeln, ohne Darstellung und ohne Zeit.
/// Animationen meldet die Darstellung über [finishPlacing]/[finishRotating].
class GameSession {
  /// [shapes] legt einen festen Vorrat fest (für Tests); sonst wächst der
  /// Vorrat mit dem Fortschritt, siehe [PieceLibrary.forProgress].
  GameSession({Rules? rules, int? seed, List<PieceShape>? shapes})
    : rules = rules ?? const Rules(),
      _bag = PieceBag(
        shapes == null ? PieceLibrary.forProgress : (_) => shapes,
        seed: seed,
      ) {
    board = Board(this.rules.config.grid);
    current = _bag.next();
    next = _bag.next();
    _centerPiece();
  }

  static const pointsPerCube = 10;
  static const pointsPerLayer = 100;
  static const pointsPerMilestone = 200;
  static const milestoneEvery = 5;
  static const comboStep = 0.1;
  static const maxMultiplier = 2.0;

  /// Multiplikator für die n-te saubere Ablage in Folge.
  static double multiplierFor(int combo) => combo <= 1
      ? 1.0
      : (1 + comboStep * (combo - 1)).clamp(1.0, maxMultiplier);

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

  /// Bei [GameOverReason.noPlacement]: warum [current] nirgends passte.
  BlockCause? blockCause;

  /// Höchste erlaubte Säulenhöhe nach der nächsten Ablage.
  int get heightLimit => board.minHeight + rules.config.maxSpread;
  int score = 0;
  int piecesPlaced = 0;
  int rotations = 0;

  /// Saubere Ablagen in Folge.
  int combo = 0;
  int bestCombo = 0;
  int _milestones = 0;
  int _fullLayers = 0;
  int _nextPieceId = 1;

  /// Anzahl gültiger Ablagen (Position x Orientierung) für den aktuellen Baustein.
  int placementsLeft = 1 << 20;

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
    final clean = p.isFullySupported;
    combo = clean ? combo + 1 : 0;
    if (combo > bestCombo) bestCombo = combo;
    final reached = board.maxHeight ~/ milestoneEvery;
    final milestones = reached > _milestones ? reached - _milestones : 0;
    _milestones += milestones;
    final base = p.cells.length * pointsPerCube;
    final s = PlacementScore(
      base: base,
      cleanBonus: clean ? base ~/ 2 : 0,
      multiplier: multiplierFor(combo),
      combo: combo,
      layers: layers,
      layerBonus: layers * pointsPerLayer,
      milestones: milestones,
      milestoneBonus: milestones * pointsPerMilestone,
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
    placementsLeft = rules.validPlacements(board, current).length;
    if (placementsLeft == 0) {
      final b = rules.blockers(board, current);
      blockCause = b.unsupported == 0
          ? BlockCause.tooUneven
          : b.tooUneven == 0
          ? BlockCause.unsupported
          : BlockCause.both;
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
