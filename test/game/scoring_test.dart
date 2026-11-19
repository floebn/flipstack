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

    test('Höhenmeilenstein alle 5 Ebenen gibt 200 Punkte, genau einmal', () {
      final s = GameSession(
        seed: 1,
        shapes: const [PieceLibrary.square],
        rules: const Rules(RuleConfig(grid: 2, maxHeight: 12)),
      );
      final bonuses = <int>[];
      for (var i = 0; i < 10; i++) {
        bonuses.add(s.place()!.$2.milestoneBonus);
        s.finishPlacing();
      }
      expect(bonuses, [0, 0, 0, 0, 200, 0, 0, 0, 0, 200]);
    });

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
        expect(sc.total, sc.placement + sc.layerBonus + sc.milestoneBonus);
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
      expect(PieceLibrary.forProgress(36).toSet(), PieceLibrary.all.toSet());
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
