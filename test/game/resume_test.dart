import 'dart:convert';
import 'dart:math' as math;

import 'package:flipstack/game/core/board.dart';
import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/core/piece.dart';
import 'package:flipstack/game/core/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void playRandom(GameSession s, math.Random rng, int moves) {
  for (var i = 0; i < moves && s.phase != GamePhase.gameOver; i++) {
    final o = s.rules.validPlacements(s.board, s.current);
    final (x, y, r) = o[rng.nextInt(o.length)];
    s.orientation = r;
    s.moveTo(x, y);
    s.place();
    s.finishPlacing();
  }
}

void main() {
  group('Volle Ebene', () {
    test('zählt auch über einer Ebene mit Lücke', () {
      final s = GameSession(seed: 1, shapes: const [PieceLibrary.single]);
      // Ebene 0 bleibt mit einer Lücke bei (4,4); darüber liegt schon ein
      // Würfel, die Lücke kann also nie mehr gefüllt werden.
      for (var i = 0; i < 24; i++) {
        s.board.add(Cell(i % 5, i ~/ 5, 0, 0));
      }
      s.board.add(const Cell(4, 4, 1, 0));
      // Ebene 1 füllen: 24 Einzelwürfel
      PlacementScore? last;
      for (var i = 0; i < 24; i++) {
        s.moveTo(i % 5, i ~/ 5);
        last = s.place()!.$2;
        s.finishPlacing();
      }
      expect(s.board.isLayerFull(0), isFalse);
      expect(s.board.isLayerFull(1), isTrue);
      expect((last!.layers, last.layerBonus), (1, 100));
      expect(s.fullLayers, 1);
    });

    test('jede Ebene zählt genau einmal', () {
      final s = GameSession(seed: 1, shapes: const [PieceLibrary.single]);
      var bonus = 0;
      for (var z = 0; z < 3; z++) {
        for (var i = 0; i < 25; i++) {
          s.moveTo(i % 5, i ~/ 5);
          bonus += s.place()!.$2.layerBonus;
          s.finishPlacing();
        }
      }
      expect(bonus, 300);
      expect(s.fullLayers, 3);
    });
  });

  group('Auflage zählt nach Würfeln', () {
    const rules = Rules();
    // Stufe: Feld A trägt einen Würfel, Feld B zwei übereinander.
    test('Stufe darf nicht nur mit dem einzelnen Würfel aufliegen', () {
      // Feld (0,0) ist erhöht: Dort liegt A auf, B (zwei Würfel) hinge frei.
      final b = Board(5)..add(const Cell(0, 0, 0, 0));
      final p = rules.evaluate(b, PieceLibrary.step, 0, 0, 0);
      expect((p.z0, p.supported, p.columns), (1, 1, 2));
      expect(p.error, PlacementError.unsupported);
    });

    test('Stufe darf mit der Zweier-Säule aufliegen', () {
      final b = Board(5)..add(const Cell(1, 0, 0, 0));
      final p = rules.evaluate(b, PieceLibrary.step, 0, 0, 0);
      expect((p.z0, p.supported, p.columns), (1, 1, 2));
      expect(p.isValid, isTrue);
      expect(p.isFullySupported, isFalse);
    });

    test('flache Bausteine verhalten sich wie bisher', () {
      final b = Board(5)..add(const Cell(1, 0, 0, 0));
      expect(rules.evaluate(b, PieceLibrary.domino, 0, 0, 0).isValid, isTrue);
      expect(
        rules.evaluate(b, PieceLibrary.bar3, 1, 0, 0).error,
        PlacementError.unsupported,
      );
    });
  });

  group('Runde fortsetzen', () {
    test('gespeicherte Runde geht mit denselben Steinen weiter', () {
      for (var seed = 1; seed <= 8; seed++) {
        final a = GameSession(seed: seed);
        playRandom(a, math.Random(seed), 30);
        if (a.phase == GamePhase.gameOver) continue;
        final b = GameSession.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
        )!;
        expect(
          (b.score, b.height, b.piecesPlaced, b.combo, b.fullLayers),
          (a.score, a.height, a.piecesPlaced, a.combo, a.fullLayers),
        );
        expect((b.current.name, b.next.name), (a.current.name, a.next.name));
        expect(b.board.cells.length, a.board.cells.length);
        // Beide Runden gleich weiterspielen: gleiche Steine, gleiche Punkte
        playRandom(a, math.Random(99), 25);
        playRandom(b, math.Random(99), 25);
        expect((b.score, b.piecesPlaced), (a.score, a.piecesPlaced));
        expect(b.current.name, a.current.name);
      }
    });

    test('beschädigte Daten ergeben keine Runde', () {
      expect(GameSession.fromJson({}), isNull);
      expect(GameSession.fromJson({'v': 1, 'bag': 'x'}), isNull);
      final ok = GameSession(seed: 2).toJson();
      expect(GameSession.fromJson({...ok, 'current': 'gibt_es_nicht'}), isNull);
      expect(
        GameSession.fromJson({
          ...ok,
          'cells': [
            [9, 0, 0, 0, 1],
          ],
        }),
        isNull,
      );
    });

    test('die zweite Chance bleibt nach dem Fortsetzen verbraucht', () {
      final a = GameSession(seed: 5);
      playRandom(a, math.Random(5), 5000);
      expect(a.revive(), isTrue);
      final b = GameSession.fromJson(a.toJson())!;
      expect(b.revived, isTrue);
    });
  });
}
