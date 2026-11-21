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

  /// Formen nach Namen (zum Wiederherstellen einer gespeicherten Runde).
  static final Map<String, PieceShape> byName = {
    for (final s in all) s.name: s,
  };

  /// Schwellen (Anzahl bereits gezogener Bausteine), ab denen neue Formen dazukommen.
  static const tierStarts = [0, 10, 22, 36];

  /// Formen eines Beutels abhängig vom Fortschritt, nach der Standardkurve.
  static List<PieceShape> forProgress(int drawn, {int height = 0}) =>
      const DifficultyCurve().pool(drawn, height);
}

/// Wie die Formenmischung mit der Turmhöhe schwerer wird. Die Schwierigkeit
/// steigt nie über Zeitdruck und nie sprunghaft: Erst kommen sperrige Formen
/// dazu, danach fallen die einfachen Lückenfüller nach und nach weg.
///
/// Alle Schwellen sind Turmhöhen. Eine Änderung wirkt mit dem nächsten Beutel.
class DifficultyCurve {
  const DifficultyCurve({
    this.fivers1 = 15,
    this.fivers2 = 25,
    this.noSingle = 30,
    this.noDomino = 35,
    this.doubleFivers = 45,
    this.dropFrom = 55,
    this.dropEvery = 10,
    this.maxLateDrops = 1,
  });

  /// Erste Fünfer (P-Form, langer Haken); der zweite Einzelwürfel entfällt.
  final int fivers1;

  /// Weitere Fünfer (U-Form, Kreuz).
  final int fivers2;

  /// Der Einzelwürfel fällt ganz weg.
  final int noSingle;

  /// Der Doppelblock fällt weg.
  final int noDomino;

  /// Alle Fünfer sind doppelt im Beutel.
  final int doubleFivers;

  /// Ab hier fällt alle [dropEvery] Ebenen ein weiterer einfacher Stein weg,
  /// in der Reihenfolge von [lateDrops].
  final int dropFrom, dropEvery;

  /// Wie viele Steine aus [lateDrops] höchstens wegfallen. Mit 1 endet die
  /// Verschärfung bei [dropFrom]: Wer weiter kommt, wird nicht mehr
  /// zusätzlich gebremst.
  final int maxLateDrops;

  static const lateDrops = [
    PieceLibrary.corner,
    PieceLibrary.bar3,
    PieceLibrary.pillar,
    PieceLibrary.square,
  ];

  /// Wie viele Steine aus [lateDrops] bei [height] schon fehlen.
  int lateDropCount(int height) => height < dropFrom
      ? 0
      : ((height - dropFrom) ~/ dropEvery + 1).clamp(
          0,
          maxLateDrops < lateDrops.length ? maxLateDrops : lateDrops.length,
        );

  List<PieceShape> pool(int drawn, int height) {
    final starts = PieceLibrary.tierStarts;
    final big1 = height >= fivers1, big2 = height >= fivers2;
    final gone = <PieceShape>{
      if (height >= noSingle) PieceLibrary.single,
      if (height >= noDomino) PieceLibrary.domino,
      ...lateDrops.take(lateDropCount(height)),
    };
    final fivers = [
      if (big1) ...PieceLibrary.tier5,
      if (big2) ...PieceLibrary.tier6,
    ];
    return [
      for (final s in [
        ...PieceLibrary.basic,
        if (drawn >= starts[1]) ...PieceLibrary.tier2,
        if (drawn >= starts[2]) ...PieceLibrary.tier3,
        if (drawn >= starts[3]) ...PieceLibrary.tier4,
        // Lückenfüller doppelt, bis die ersten Fünfer kommen
        if (drawn >= starts[3] && !big1) PieceLibrary.single,
      ])
        if (!gone.contains(s)) s,
      ...fivers,
      if (height >= doubleFivers) ...fivers,
    ];
  }

  /// Was sich beim Erreichen von [height] ändert (für die Ansage im Spiel),
  /// oder `null`.
  String? changeAt(int height) {
    if (height == fivers1) return 'Bald kommen Formen aus fünf Würfeln';
    if (height == fivers2) return 'Bald kommen noch sperrigere Formen';
    if (height == noSingle) return 'Bald gibt es keine Einzelwürfel mehr';
    if (height == noDomino) return 'Bald gibt es keine Doppelblöcke mehr';
    if (height == doubleFivers) return 'Bald kommen die Fünfer doppelt so oft';
    if (height >= dropFrom &&
        (height - dropFrom) % dropEvery == 0 &&
        lateDropCount(height) > lateDropCount(height - 1)) {
      return 'Bald fällt ein weiterer einfacher Stein weg';
    }
    return null;
  }
}
