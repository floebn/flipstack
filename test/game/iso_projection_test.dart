import 'dart:math' as math;

import 'package:flipstack/game/projection/iso_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = IsoProjection(origin: const Offset(100, 200), unit: 10);

  test('Ursprung liegt auf origin', () {
    expect(p.project(0, 0, 0), const Offset(100, 200));
  });

  test('Achsen: +x nach rechts unten, +y nach rechts oben, +z nach oben', () {
    final x = p.project(1, 0, 0),
        y = p.project(0, 1, 0),
        z = p.project(0, 0, 1);
    expect(x.dx, closeTo(107.071, 1e-3));
    expect(x.dy, closeTo(204.082, 1e-3));
    expect(y.dx, closeTo(107.071, 1e-3));
    expect(y.dy, closeTo(195.918, 1e-3));
    expect(z.dx, closeTo(100, 1e-9));
    expect(z.dy, closeTo(191.835, 1e-3));
  });

  test('Vier Vierteldrehungen ergeben die Ausgangslage', () {
    final a = p.project(1.5, -2, 3);
    final b = p.project(1.5, -2, 3, 2 * math.pi);
    expect(b.dx, closeTo(a.dx, 1e-9));
    expect(b.dy, closeTo(a.dy, 1e-9));
  });

  test('90°-Drehung bildet (x, y) auf (-y, x) ab', () {
    final (x, y) = IsoProjection.rotate(2, 1, math.pi / 2);
    expect(x, closeTo(-1, 1e-12));
    expect(y, closeTo(2, 1e-12));
  });

  test('Tiefe: vorne, rechts und oben liegen näher an der Kamera', () {
    expect(
      IsoProjection.depth(1, 0, 0),
      greaterThan(IsoProjection.depth(0, 0, 0)),
    );
    expect(
      IsoProjection.depth(0, -1, 0),
      greaterThan(IsoProjection.depth(0, 0, 0)),
    );
    expect(
      IsoProjection.depth(0, 0, 1),
      greaterThan(IsoProjection.depth(0, 0, 0)),
    );
  });

  test(
    'Höhe ändert die Bildschirmposition unabhängig vom Drehwinkel gleich',
    () {
      for (final t in [0.0, 0.3, 1.1, 2.9]) {
        final d = p.project(1, 2, 1, t) - p.project(1, 2, 0, t);
        expect(d.dx, closeTo(0, 1e-9));
        expect(d.dy, closeTo(-8.165, 1e-3));
      }
    },
  );
}
