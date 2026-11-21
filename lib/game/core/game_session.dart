import 'board.dart';
import 'orientation.dart';
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
    this.stage = 0,
    this.stageBonus = 0,
    this.newSpread,
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

  /// Erreichte Etappe (Turmhöhe 10, 20, 30 ...) oder 0.
  final int stage;
  final int stageBonus;

  /// Mit dieser Ablage neu geltender, engerer Höhenunterschied (sonst `null`).
  final int? newSpread;

  int get total => placement + layerBonus + milestoneBonus + stageBonus;
}

/// Eine Spielrunde: reiner Zustand und Regeln, ohne Darstellung und ohne Zeit.
/// Animationen meldet die Darstellung über [finishPlacing]/[finishRotating].
class GameSession {
  /// [shapes] legt einen festen Vorrat fest (für Tests); sonst wächst der
  /// Vorrat mit dem Fortschritt, siehe [PieceLibrary.forProgress].
  /// [pool] ersetzt die Formenmischung ganz (für die Simulation).
  GameSession({
    Rules? rules,
    int? seed,
    List<PieceShape>? shapes,
    List<PieceShape> Function(int drawn, int height)? pool,
    this.curve = const DifficultyCurve(),
  }) : rules = rules ?? const Rules() {
    board = Board(this.rules.config.grid);
    _bag = PieceBag(
      shapes != null
          ? (_) => shapes
          : pool != null
          ? (drawn) => pool(drawn, board.maxHeight)
          : (drawn) => curve.pool(drawn, board.maxHeight),
      seed: seed,
    );
    current = _bag.next();
    next = _bag.next();
    _centerPiece();
  }

  static const pointsPerCube = 10;
  static const pointsPerLayer = 100;
  static const pointsPerMilestone = 200;
  static const milestoneEvery = 5;

  /// Jeder zweite Meilenstein (Höhe 10, 20, 30 ...) ist eine Etappe.
  static const stageEvery = 10;
  static const pointsPerStage = 500;
  static const comboStep = 0.1;
  static const maxMultiplier = 2.0;

  /// Multiplikator für die n-te saubere Ablage in Folge.
  static double multiplierFor(int combo) => combo <= 1
      ? 1.0
      : (1 + comboStep * (combo - 1)).clamp(1.0, maxMultiplier);

  final Rules rules;

  /// Wie die Formenmischung mit der Höhe schwerer wird.
  final DifficultyCurve curve;
  late final PieceBag _bag;
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
  int get heightLimit => board.minHeight + maxSpread;

  /// Aktuell erlaubter Höhenunterschied (wird mit der Turmhöhe enger).
  int get maxSpread => rules.config.spreadAt(board.maxHeight);
  int score = 0;
  int piecesPlaced = 0;
  int rotations = 0;

  /// Saubere Ablagen in Folge.
  int combo = 0;
  int bestCombo = 0;

  /// Anzahl sauberer Ablagen in dieser Runde.
  int cleanPlacements = 0;

  /// Vollständig gefüllte Ebenen dieser Runde.
  int get fullLayers => _countedLayers.length;
  final Set<int> _countedLayers = {};
  int _milestones = 0;
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
    final spreadBefore = maxSpread;
    for (final (x, y, z) in p.cells) {
      board.add(Cell(x, y, z, current.color, id));
    }
    var layers = 0;
    // Jede Ebene, die diese Ablage vollständig macht, zählt einmal, auch
    // wenn weiter unten eine Lücke unter einem Überhang offen geblieben ist.
    for (final z in {for (final c in p.cells) c.$3}) {
      if (!_countedLayers.contains(z) && board.isLayerFull(z)) {
        _countedLayers.add(z);
        layers++;
      }
    }
    final clean = p.isFullySupported;
    combo = clean ? combo + 1 : 0;
    if (clean) cleanPlacements++;
    if (combo > bestCombo) bestCombo = combo;
    // Meilensteine alle 5 Ebenen; jeder zweite ist eine Etappe.
    final reached = board.maxHeight ~/ milestoneEvery;
    var milestones = 0, stage = 0;
    for (var m = _milestones + 1; m <= reached; m++) {
      if (m * milestoneEvery % stageEvery == 0) {
        stage = m * milestoneEvery;
      } else {
        milestones++;
      }
    }
    if (reached > _milestones) _milestones = reached;
    final spreadAfter = maxSpread;
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
      stage: stage,
      stageBonus: stage > 0 ? pointsPerStage : 0,
      newSpread: spreadAfter < spreadBefore ? spreadAfter : null,
    );
    score += s.total;
    piecesPlaced++;
    phase = GamePhase.placing;
    return (p, s, id);
  }

  /// Nach der Fallanimation: nächsten Baustein holen oder Runde beenden.
  void finishPlacing() {
    if (phase != GamePhase.placing) return;
    final cap = rules.config.maxHeight;
    if (cap != null && board.maxHeight >= cap) {
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

  /// Speichert die Runde, damit sie nach dem Schliessen der App fortgesetzt
  /// werden kann. Nur in Ruhe sinnvoll (kein Stein fällt, Runde läuft).
  Map<String, dynamic> toJson() => {
    'v': 1,
    'bag': _bag.toJson(),
    'cells': [
      for (final c in board.cells) [c.x, c.y, c.z, c.color, c.pieceId],
    ],
    'current': current.name,
    'next': next.name,
    'orientation': Orientation.normalize(orientation),
    'score': score,
    'pieces': piecesPlaced,
    'rotations': rotations,
    'combo': combo,
    'bestCombo': bestCombo,
    'clean': cleanPlacements,
    'milestones': _milestones,
    'layers': _countedLayers.toList(),
    'nextId': _nextPieceId,
    'revived': revived,
  };

  /// Stellt eine mit [toJson] gespeicherte Runde wieder her. Liefert `null`,
  /// wenn die Daten unvollständig oder beschädigt sind oder die Runde nicht
  /// mehr spielbar wäre.
  static GameSession? fromJson(Map<String, dynamic> j) {
    try {
      if (j['v'] != 1) return null;
      final bag = (j['bag'] as Map).cast<String, dynamic>();
      final s = GameSession(seed: bag['seed'] as int);
      s._bag.restore(bag);
      for (final c in j['cells'] as List) {
        final v = (c as List).cast<int>();
        if (v[0] < 0 || v[1] < 0 || v[0] >= s.grid || v[1] >= s.grid) {
          return null;
        }
        s.board.add(Cell(v[0], v[1], v[2], v[3], v[4]));
      }
      final current = PieceLibrary.byName[j['current']];
      final next = PieceLibrary.byName[j['next']];
      if (current == null || next == null) return null;
      s
        ..current = current
        ..next = next
        ..orientation = j['orientation'] as int
        ..score = j['score'] as int
        ..piecesPlaced = j['pieces'] as int
        ..rotations = j['rotations'] as int
        ..combo = j['combo'] as int
        ..bestCombo = j['bestCombo'] as int
        ..cleanPlacements = j['clean'] as int
        .._milestones = j['milestones'] as int
        .._nextPieceId = j['nextId'] as int
        ..revived = j['revived'] == true;
      s._countedLayers.addAll((j['layers'] as List).cast<int>());
      s._centerPiece();
      s.placementsLeft = s.rules.validPlacements(s.board, s.current).length;
      return s.placementsLeft > 0 ? s : null;
    } catch (_) {
      return null;
    }
  }

  /// Die zweite Chance wurde in dieser Runde schon genutzt.
  bool revived = false;

  /// Zweite Chance ist möglich: Die Runde endete, weil ein Stein nirgends
  /// passte, und sie wurde noch nicht fortgesetzt.
  bool get canRevive =>
      phase == GamePhase.gameOver &&
      gameOverReason == GameOverReason.noPlacement &&
      !revived;

  /// Setzt die Runde einmal fort: Der Stein, der nirgends passte, wird gegen
  /// den nächsten getauscht, der passt (notfalls ein Einzelwürfel, der immer
  /// auf das tiefste Feld passt). Der Turm bleibt, wie er ist.
  bool revive() {
    if (!canRevive) return false;
    revived = true;
    var piece = next;
    for (var i = 0; i < 40 && !rules.hasAnyValidPlacement(board, piece); i++) {
      piece = _bag.next();
    }
    if (!rules.hasAnyValidPlacement(board, piece)) piece = PieceLibrary.single;
    current = piece;
    next = _bag.next();
    _centerPiece();
    placementsLeft = rules.validPlacements(board, current).length;
    gameOverReason = null;
    blockCause = null;
    phase = GamePhase.preview;
    return true;
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
