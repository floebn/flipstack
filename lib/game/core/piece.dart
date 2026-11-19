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

/// Alle Bausteine. Farbindex: 0 mint, 1 coral, 2 amber, 3 cream, 4 sky,
/// 5 plum, 6 leaf, 7 rose (siehe `FsColors.blocks`). Jede Form hat eine feste
/// Farbe, damit sie auf einen Blick erkennbar ist.
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
  ], 4);
  static const tee = PieceShape('tee', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (1, 1, 0),
  ], 5);

  /// Stehender Doppelblock (zwei Würfel hoch).
  static const pillar = PieceShape('pillar', [(0, 0, 0), (0, 0, 1)], 6);
  static const bar4 = PieceShape('bar4', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (3, 0, 0),
  ], 0);
  static const ell = PieceShape('ell', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (0, 1, 0),
  ], 7);
  static const jay = PieceShape('jay', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (2, 1, 0),
  ], 4);
  static const ess = PieceShape('ess', [
    (0, 0, 0),
    (1, 0, 0),
    (1, 1, 0),
    (2, 1, 0),
  ], 1);
  static const zed = PieceShape('zed', [
    (1, 0, 0),
    (2, 0, 0),
    (0, 1, 0),
    (1, 1, 0),
  ], 5);

  /// Stufe: liegender Doppelblock mit aufgesetztem Würfel.
  static const step = PieceShape('step', [(0, 0, 0), (1, 0, 0), (1, 0, 1)], 2);

  // Formen aus fünf Würfeln, kommen erst in grosser Höhe dazu.
  static const pentoP = PieceShape('pento_p', [
    (0, 0, 0),
    (1, 0, 0),
    (0, 1, 0),
    (1, 1, 0),
    (0, 2, 0),
  ], 6);
  static const pentoU = PieceShape('pento_u', [
    (0, 0, 0),
    (2, 0, 0),
    (0, 1, 0),
    (1, 1, 0),
    (2, 1, 0),
  ], 3);
  static const plus = PieceShape('plus', [
    (1, 0, 0),
    (0, 1, 0),
    (1, 1, 0),
    (2, 1, 0),
    (1, 2, 0),
  ], 7);
  static const hook = PieceShape('hook', [
    (0, 0, 0),
    (1, 0, 0),
    (2, 0, 0),
    (3, 0, 0),
    (0, 1, 0),
  ], 2);

  static const basic = [single, domino, bar3, corner, square];
  static const tier2 = [tee, pillar];
  static const tier3 = [bar4, ell, jay];
  static const tier4 = [ess, zed, step];
  static const tier5 = [pentoP, hook];
  static const tier6 = [pentoU, plus];
  static const all = [
    ...basic,
    ...tier2,
    ...tier3,
    ...tier4,
    ...tier5,
    ...tier6,
  ];

  /// Schwellen (Anzahl bereits gezogener Bausteine), ab denen neue Formen dazukommen.
  static const tierStarts = [0, 10, 22, 36];

  /// Turmhöhen, ab denen die Formen aus fünf Würfeln dazukommen
  /// ([tier5], dann [tier6]).
  static const bigPiecesFromHeight = [20, 30];

  /// Formen eines Beutels abhängig vom Fortschritt. Die Schwierigkeit steigt
  /// über die Formenmischung, nicht über Zeitdruck. In der vierten Stufe ist
  /// der Einzelwürfel als Lückenfüller doppelt im Beutel. Mit den ersten
  /// Fünfern entfällt der zweite Einzelwürfel wieder.
  static List<PieceShape> forProgress(int drawn, {int height = 0}) {
    final big = height >= bigPiecesFromHeight[0];
    return [
      ...basic,
      if (drawn >= tierStarts[1]) ...tier2,
      if (drawn >= tierStarts[2]) ...tier3,
      if (drawn >= tierStarts[3]) ...tier4,
      if (drawn >= tierStarts[3] && !big) single,
      if (big) ...tier5,
      if (height >= bigPiecesFromHeight[1]) ...tier6,
    ];
  }
}
