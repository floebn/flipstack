import 'dart:math' as math;

import 'package:flipstack/game/core/board.dart';
import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/core/orientation.dart';
import 'package:flipstack/game/core/piece.dart';
import 'package:flipstack/game/core/piece_bag.dart';
import 'package:flipstack/game/core/rules.dart';
import 'package:flipstack/game/projection/iso_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Orientation', () {
    test('Hin- und Rückabbildung heben sich für alle Orientierungen auf', () {
      for (var r = -5; r <= 5; r++) {
        for (var x = 0; x < 5; x++) {
          for (var y = 0; y < 5; y++) {
            final (wx, wy) = Orientation.platformToWorld(x, y, r, 5);
            expect(Orientation.worldToPlatform(wx, wy, r, 5), (x, y));
          }
        }
      }
    });

    test('stimmt mit der Drehung der Projektion überein', () {
      for (var r = 0; r < 4; r++) {
        final (wx, wy) = Orientation.platformToWorld(0, 1, r, 5);
        final (fx, fy) = IsoProjection.rotate(
          0 - 2.0,
          1 - 2.0,
          r * math.pi / 2,
        );
        expect(wx - 2, closeTo(fx, 1e-9));
        expect(wy - 2, closeTo(fy, 1e-9));
      }
    });

    test('vier Drehungen = Ausgangslage, Brettdaten bleiben unverändert', () {
      final s = GameSession(seed: 1);
      s.place();
      s.finishPlacing();
      final before = [for (final c in s.board.cells) (c.x, c.y, c.z)];
      for (var i = 0; i < 4; i++) {
        expect(s.rotate(1), isTrue);
        s.finishRotating();
      }
      expect(Orientation.normalize(s.orientation), 0);
      expect([for (final c in s.board.cells) (c.x, c.y, c.z)], before);
    });
  });

  group('Rules', () {
    const rules = Rules();

    test('leeres Brett: Baustein landet auf Höhe 0 und ist voll gestützt', () {
      final p = rules.evaluate(Board(5), PieceLibrary.square, 1, 1, 0);
      expect(p.isValid, isTrue);
      expect(p.z0, 0);
      expect(p.isFullySupported, isTrue);
      expect(p.cells.length, 4);
    });

    test('ausserhalb des Rasters ist ungültig', () {
      expect(
        rules.evaluate(Board(5), PieceLibrary.bar3, 3, 0, 0).error,
        PlacementError.outOfBounds,
      );
      expect(
        rules.evaluate(Board(5), PieceLibrary.bar3, -1, 0, 0).error,
        PlacementError.outOfBounds,
      );
    });

    test('Baustein landet auf der höchsten Säule unter ihm', () {
      final b = Board(5)..add(const Cell(1, 0, 0, 0));
      final p = rules.evaluate(b, PieceLibrary.domino, 0, 0, 0);
      expect(p.z0, 1);
      expect(p.supported, 1);
      expect(p.isValid, isTrue); // 50 % Auflage genügt
    });

    test('zu wenig Auflage ist ungültig', () {
      final b = Board(5)..add(const Cell(0, 0, 0, 0));
      final p = rules.evaluate(b, PieceLibrary.bar3, 0, 0, 0);
      expect(p.supported, 1);
      expect(p.error, PlacementError.unsupported);
      expect(
        const Rules(RuleConfig(minSupport: 1 / 3))
            .evaluate(b, PieceLibrary.bar3, 0, 0, 0)
            .isValid,
        isTrue,
      );
    });

    test('zu grosser Höhenunterschied ist ungültig', () {
      final b = Board(5);
      for (var z = 0; z < 4; z++) {
        b.add(Cell(0, 0, z, 0));
      }
      expect(
        rules.evaluate(b, PieceLibrary.single, 0, 0, 0).error,
        PlacementError.tooUneven,
      );
      expect(rules.evaluate(b, PieceLibrary.single, 1, 0, 0).isValid, isTrue);
    });

    test('Platzierung nach Drehung trifft die gedrehte Plattformzelle', () {
      final p = rules.evaluate(Board(5), PieceLibrary.single, 0, 0, 1);
      expect(p.cells.single, (0, 4, 0));
    });

    test('Drehung macht einen Baustein passend', () {
      // Reihe y=0 ist bis auf die Spalte x=0 um 1 erhöht; der senkrechte Schlitz
      // bei x=0 passt nur, wenn der waagerechte Dreier quer dazu liegt.
      final b = Board(5);
      for (var x = 1; x < 5; x++) {
        for (var y = 0; y < 5; y++) {
          b.add(Cell(x, y, 0, 0));
        }
      }
      final flat = rules.evaluate(b, PieceLibrary.bar3, 0, 0, 0);
      expect(flat.z0, 1);
      final turned = [
        for (final (x, y, r) in rules.validPlacements(b, PieceLibrary.bar3))
          rules.evaluate(b, PieceLibrary.bar3, x, y, r),
      ].where((p) => p.z0 == 0);
      expect(turned, isNotEmpty);
    });

    test('kein gültiger Platz wird erkannt', () {
      final b = Board(5);
      // Schachbrett aus 4er-Türmen: jeder Baustein läge zu hoch oder zu schlecht auf.
      for (var x = 0; x < 5; x++) {
        for (var y = 0; y < 5; y++) {
          if ((x + y).isEven) {
            for (var z = 0; z < 4; z++) {
              b.add(Cell(x, y, z, 0));
            }
          }
        }
      }
      expect(rules.hasAnyValidPlacement(b, PieceLibrary.square), isFalse);
      expect(rules.hasAnyValidPlacement(b, PieceLibrary.single), isTrue);
    });
  });

  group('GameSession', () {
    test('Ablegen vergibt 10 Punkte je Würfel und wechselt den Zustand', () {
      final s = GameSession(seed: 3);
      final cubes = s.current.cells.length;
      final r = s.place()!;
      expect(r.$2.base, cubes * 10);
      expect(
        s.score,
        cubes * 15,
        reason: '10 je Würfel + 50 % für saubere Ablage',
      );
      expect(s.phase, GamePhase.placing);
      expect(s.place(), isNull, reason: 'während des Fallens gesperrt');
      expect(s.rotate(1), isFalse);
      s.finishPlacing();
      expect(s.phase, GamePhase.preview);
    });

    test('während der Drehung kann nicht abgelegt werden', () {
      final s = GameSession(seed: 3);
      expect(s.rotate(-1), isTrue);
      expect(s.phase, GamePhase.rotating);
      expect(s.place(), isNull);
      expect(s.rotate(1), isFalse);
      s.finishRotating();
      expect(s.place(), isNotNull);
    });

    test('volle Ebene gibt 100 Bonuspunkte', () {
      final s = GameSession(seed: 1, shapes: const [PieceLibrary.single]);
      PlacementScore? last;
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          s.moveTo(x, y);
          last = s.place()!.$2;
          s.finishPlacing();
        }
      }
      expect(last!.layers, 1);
      expect(last.layerBonus, 100);
      expect(
        s.score,
        greaterThan(25 * 15 + 100),
        reason: 'Combo erhöht die Punkte',
      );
      expect(s.height, 1);
    });

    test('Verschieben bleibt im Raster', () {
      final s = GameSession(seed: 1, shapes: const [PieceLibrary.bar3]);
      s.moveTo(9, -4);
      expect((s.wx, s.wy), (2, 0));
    });

    test('Runde endet, wenn nichts mehr passt, und bleibt dann gesperrt', () {
      final s = GameSession(seed: 5);
      final rng = math.Random(5);
      while (s.phase != GamePhase.gameOver) {
        final o = s.rules.validPlacements(s.board, s.current);
        expect(o, isNotEmpty);
        final (x, y, r) = o[rng.nextInt(o.length)];
        s.orientation = r;
        s.moveTo(x, y);
        expect(s.place(), isNotNull);
        s.finishPlacing();
      }
      expect(s.gameOverReason, GameOverReason.noPlacement);
      expect(s.place(), isNull);
      expect(s.rotate(1), isFalse);
    });

    test('Maximalhöhe beendet die Runde als Gipfel', () {
      final s = GameSession(
        seed: 1,
        shapes: const [PieceLibrary.square],
        rules: const Rules(RuleConfig(grid: 2, maxHeight: 3)),
      );
      for (var i = 0; i < 3; i++) {
        s.place();
        s.finishPlacing();
      }
      expect(s.gameOverReason, GameOverReason.summit);
    });
  });

  test(
    'PieceBag: gleicher Seed, gleiche Folge; jede Form einmal pro Beutel',
    () {
      final a = PieceBag((_) => PieceLibrary.basic, seed: 7),
          b = PieceBag((_) => PieceLibrary.basic, seed: 7);
      final first = [for (var i = 0; i < 5; i++) a.next().name];
      expect(first.toSet().length, 5);
      expect([for (var i = 0; i < 5; i++) b.next().name], first);
    },
  );
}
