import 'dart:math' as math;

import 'package:flipstack/game/core/board.dart';
import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/core/piece.dart';
import 'package:flipstack/game/core/player_stats.dart';
import 'package:flipstack/game/core/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Punkte und Combo', () {
    test('Multiplikator steigt je sauberer Ablage um 0,1 bis höchstens 2', () {
      expect(GameSession.multiplierFor(0), 1.0);
      expect(GameSession.multiplierFor(1), 1.0);
      expect(GameSession.multiplierFor(2), 1.1);
      expect(GameSession.multiplierFor(5), closeTo(1.4, 1e-9));
      expect(GameSession.multiplierFor(50), 2.0);
    });

    test('saubere Ablagen bauen die Combo auf, ein Überhang beendet sie', () {
      final s = GameSession(seed: 1, shapes: const [PieceLibrary.domino]);
      s.moveTo(0, 0);
      var r = s.place()!.$2;
      s.finishPlacing();
      expect((r.clean, r.combo, r.placement), (true, 1, 30));
      s.moveTo(2, 0);
      r = s.place()!.$2;
      s.finishPlacing();
      expect((r.combo, r.multiplier, r.placement), (2, 1.1, 33));
      // halb auf einem Stein, halb in der Luft: gültig, aber nicht sauber
      final o = s.rules
          .validPlacements(s.board, s.current)
          .map(
            (c) => (c, s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3)),
          )
          .firstWhere((e) => !e.$2.isFullySupported);
      s.orientation = o.$1.$3;
      s.moveTo(o.$1.$1, o.$1.$2);
      r = s.place()!.$2;
      expect(
        (r.clean, r.combo, r.multiplier, r.placement),
        (false, 0, 1.0, 20),
      );
      expect(s.bestCombo, 2);
    });

    test(
      'Meilenstein bei 5, 15 ... gibt 200, Etappe bei 10, 20 ... gibt 500',
      () {
        final s = GameSession(
          seed: 1,
          shapes: const [PieceLibrary.square],
          rules: const Rules(RuleConfig(grid: 2, maxHeight: 12)),
        );
        final bonuses = <int>[], stages = <int>[];
        for (var i = 0; i < 10; i++) {
          final sc = s.place()!.$2;
          bonuses.add(sc.milestoneBonus + sc.stageBonus);
          stages.add(sc.stage);
          s.finishPlacing();
        }
        expect(bonuses, [0, 0, 0, 0, 200, 0, 0, 0, 0, 500]);
        expect(stages, [0, 0, 0, 0, 0, 0, 0, 0, 0, 10]);
      },
    );

    test('Punktestand ist die Summe der ausgewiesenen Einzelposten', () {
      final s = GameSession(seed: 4);
      final rng = math.Random(4);
      var sum = 0;
      while (s.phase != GamePhase.gameOver) {
        final o = s.rules.validPlacements(s.board, s.current);
        final (x, y, r) = o[rng.nextInt(o.length)];
        s.orientation = r;
        s.moveTo(x, y);
        final sc = s.place()!.$2;
        expect(
          sc.total,
          sc.placement + sc.layerBonus + sc.milestoneBonus + sc.stageBonus,
        );
        sum += sc.total;
        s.finishPlacing();
      }
      expect(s.score, sum);
    });
  });

  group('Bausteine mit Höhe', () {
    test('stehender Baustein landet mit seiner Unterkante', () {
      final b = Board(5)..add(const Cell(0, 0, 0, 0));
      final p = const Rules().evaluate(b, PieceLibrary.pillar, 0, 0, 0);
      expect(p.z0, 1);
      expect(p.cells, [(0, 0, 1), (0, 0, 2)]);
      expect(p.columns, 1);
    });

    test('Stufe ruht auf ihrer unteren Ebene', () {
      final p = const Rules().evaluate(Board(5), PieceLibrary.step, 0, 0, 0);
      expect(p.z0, 0);
      expect(p.columns, 2);
      expect(p.isFullySupported, isTrue);
    });
  });

  group('Ursache des Spielendes', () {
    Board tower(int h) {
      final b = Board(5);
      for (var z = 0; z < h; z++) {
        b.add(Cell(0, 0, z, 0));
      }
      return b;
    }

    test('Höhengrenze = niedrigste Säule + 4', () {
      final s = GameSession(seed: 1);
      expect(s.heightLimit, 4);
    });

    test('scheitert nur am Höhenunterschied', () {
      // Ein 4er-Turm in der Ecke, sonst leer: Der Einzelwürfel passt überall
      // ausser auf den Turm, und dort scheitert er an der Höhe.
      final b = const Rules().blockers(tower(4), PieceLibrary.single);
      expect(b.unsupported, 0);
      expect(
        b.tooUneven,
        4,
        reason: 'dieselbe Zelle in allen vier Orientierungen',
      );
    });

    test('scheitert an zu wenig Auflage', () {
      final b = const Rules().blockers(tower(1), PieceLibrary.bar4);
      expect(b.unsupported, greaterThan(0));
      expect(b.tooUneven, 0);
    });

    test('nach "kein Platz mehr" ist die Ursache gesetzt und plausibel', () {
      for (final seed in [1, 2, 3, 4, 5, 6]) {
        final s = GameSession(seed: seed);
        final rng = math.Random(seed);
        while (s.phase != GamePhase.gameOver) {
          final o = s.rules.validPlacements(s.board, s.current);
          final (x, y, r) = o[rng.nextInt(o.length)];
          s.orientation = r;
          s.moveTo(x, y);
          s.place();
          s.finishPlacing();
        }
        final b = s.rules.blockers(s.board, s.current);
        expect(s.blockCause, isNotNull);
        expect(b.unsupported + b.tooUneven, greaterThan(0));
        if (s.blockCause == BlockCause.tooUneven) expect(b.unsupported, 0);
        if (s.blockCause == BlockCause.unsupported) expect(b.tooUneven, 0);
      }
    });
  });

  group('Fortschritt und Statistik', () {
    test('neue Formen kommen stufenweise dazu', () {
      expect(PieceLibrary.forProgress(0), PieceLibrary.basic);
      expect(PieceLibrary.forProgress(10), contains(PieceLibrary.pillar));
      expect(PieceLibrary.forProgress(21), isNot(contains(PieceLibrary.bar4)));
      expect(PieceLibrary.forProgress(22), contains(PieceLibrary.bar4));
      final late = PieceLibrary.forProgress(36);
      expect(late, containsAll(PieceLibrary.tier4));
      expect(late.where((s) => s == PieceLibrary.single).length, 2);
      expect(late, isNot(contains(PieceLibrary.pentoP)));
    });

    test('Kurve: erst kommen Fünfer dazu, dann fallen einfache Steine weg', () {
      const c = DifficultyCurve();
      int count(int h, PieceShape p) =>
          c.pool(100, h).where((s) => s == p).length;
      expect(c.pool(100, 14), isNot(contains(PieceLibrary.pentoP)));
      expect(c.pool(100, 15), containsAll(PieceLibrary.tier5));
      expect(c.pool(100, 24), isNot(contains(PieceLibrary.plus)));
      expect(c.pool(100, 25), containsAll(PieceLibrary.tier6));
      // Einzelwürfel: doppelt, dann einfach, dann weg
      expect(
        [
          count(14, PieceLibrary.single),
          count(15, PieceLibrary.single),
          count(30, PieceLibrary.single),
        ],
        [2, 1, 0],
      );
      expect(
        [count(34, PieceLibrary.domino), count(35, PieceLibrary.domino)],
        [1, 0],
      );
      // Fünfer doppelt ab 45
      expect(
        [count(44, PieceLibrary.plus), count(45, PieceLibrary.plus)],
        [1, 2],
      );
      // bei 55 fällt die Ecke weg, danach wird nichts mehr schwerer
      expect(
        [count(54, PieceLibrary.corner), count(55, PieceLibrary.corner)],
        [1, 0],
      );
      String bag(int h) => c.pool(100, h).map((s) => s.name).join(',');
      for (final h in [60, 80, 150, 400]) {
        expect(bag(h), bag(55), reason: 'ab 55 unverändert (Höhe $h)');
      }
      expect(c.pool(100, 400), contains(PieceLibrary.square));
    });

    test('jede Änderung der Kurve wird genau einmal angesagt', () {
      const c = DifficultyCurve();
      final announced = [
        for (var h = 1; h <= 100; h++)
          if (c.changeAt(h) != null) h,
      ];
      expect(announced, [15, 25, 30, 35, 45, 55]);
      for (final h in announced) {
        expect(
          c.pool(100, h).map((s) => s.name).join(','),
          isNot(c.pool(100, h - 1).map((s) => s.name).join(',')),
          reason: 'Höhe $h',
        );
      }
    });

    test('auch mit dem kleinsten Beutel bleibt die Runde spielbar', () {
      final s = GameSession(seed: 3);
      for (var z = 0; z < 70; z++) {
        for (var i = 0; i < 25; i++) {
          s.board.add(Cell(i % 5, i ~/ 5, z, 0));
        }
      }
      for (var i = 0; i < 30 && s.phase != GamePhase.gameOver; i++) {
        final (x, y, r) = s.rules.validPlacements(s.board, s.current).first;
        s.orientation = r;
        s.moveTo(x, y);
        expect(s.place(), isNotNull);
        s.finishPlacing();
      }
      expect(s.piecesPlaced, greaterThan(3));
    });

    test(
      'Höhenunterschied wird ab Höhe 10 enger, Bestehendes bleibt gültig',
      () {
        const cfg = RuleConfig();
        expect(
          (cfg.spreadAt(9), cfg.spreadAt(10), cfg.spreadAt(80)),
          (4, 3, 3),
        );
        // Säule 10 hoch, Rest 6: Unterschied 4 steht schon, neu gilt 3.
        final b = Board(5);
        for (var i = 0; i < 25; i++) {
          for (var z = 0; z < (i == 0 ? 10 : 6); z++) {
            b.add(Cell(i % 5, i ~/ 5, z, 0));
          }
        }
        const rules = Rules();
        expect(
          rules.evaluate(b, PieceLibrary.single, 0, 0, 0).isValid,
          isFalse,
        );
        expect(rules.evaluate(b, PieceLibrary.square, 2, 2, 0).isValid, isTrue);
        expect(rules.evaluate(b, PieceLibrary.pillar, 2, 2, 0).isValid, isTrue);
        expect(rules.hasAnyValidPlacement(b, PieceLibrary.bar4), isTrue);
      },
    );

    test('ohne Obergrenze endet die Runde nie als Gipfel', () {
      final s = GameSession(
        seed: 1,
        shapes: const [PieceLibrary.square],
        rules: const Rules(RuleConfig(grid: 2)),
      );
      PlacementScore? last;
      for (var i = 0; i < 40; i++) {
        last = s.place()!.$2;
        s.finishPlacing();
      }
      expect(s.phase, GamePhase.preview);
      expect(s.height, 40);
      expect(last!.stage, 40);
      expect(s.maxSpread, 3);
    });

    test('Anzahl verbleibender Ablagen wird für die Vorwarnung mitgeführt', () {
      final s = GameSession(seed: 2);
      s.place();
      s.finishPlacing();
      expect(
        s.placementsLeft,
        s.rules.validPlacements(s.board, s.current).length,
      );
      expect(s.placementsLeft, greaterThan(0));
    });

    test('Statistik sammelt Runden und übersteht Speichern und Laden', () {
      var stats = const PlayerStats();
      for (final seed in [1, 2, 3]) {
        final s = GameSession(seed: seed);
        final rng = math.Random(seed);
        while (s.phase != GamePhase.gameOver) {
          final o = s.rules.validPlacements(s.board, s.current);
          final (x, y, r) = o[rng.nextInt(o.length)];
          s.orientation = r;
          s.moveTo(x, y);
          s.place();
          s.finishPlacing();
        }
        stats = stats.recordRound(s);
      }
      expect(stats.rounds, 3);
      expect(stats.bestScore, greaterThan(0));
      expect(stats.averageScore, (stats.totalScore / 3).round());
      expect(stats.totalPieces, greaterThan(10));
      expect(PlayerStats.fromJson(stats.toJson()).toJson(), stats.toJson());
    });

    test('fehlerhafte gespeicherte Daten ergeben eine leere Statistik', () {
      final s = PlayerStats.fromJson({'bestScore': 'x', 'rounds': -4});
      expect((s.bestScore, s.rounds), (0, 0));
    });
  });
}
