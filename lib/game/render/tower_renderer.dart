import 'dart:math' as math;
import 'dart:ui';

import '../core/piece.dart';
import '../projection/iso_projection.dart';
import 'sprite_set.dart';

/// Ein zu zeichnender Würfel in Weltkoordinaten (bereits gedreht, zentriert).
class RenderCube {
  RenderCube({
    required this.wx,
    required this.wy,
    required this.z,
    required this.color,
    required this.frame,
    this.opacity = 1,
    this.invalid = false,
    this.squash = 1,
    this.shadowTop,
    this.solid = true,
  });

  /// Würfelmitte.
  final double wx, wy, z;
  final int color;
  final int frame;
  final double opacity;

  /// Rot eingefärbt (ungültige Vorschau).
  final bool invalid;

  /// Vertikale Stauchung beim Aufprall (1 = keine).
  final double squash;

  /// Falls die Oberseite frei liegt: Plattformzelle (x, y) und Höhe der
  /// Oberseite, damit Schatten anderer Säulen darauf gezeichnet werden.
  final (int, int, int)? shadowTop;

  /// Fugen zu Nachbarwürfeln dunkel füllen (für feste Würfel, nicht für die Vorschau).
  final bool solid;
}

/// Zeichnet Plattform, Schatten und Würfel für einen beliebigen Drehwinkel
/// (Sprite-Komposition). Kennt keinen Spielzustand.
class TowerRenderer {
  TowerRenderer(this.sprites, {this.grid = 5});

  final SpriteSet sprites;
  final int grid;

  static const _shadowColor = Color(0x52101820);
  static const _invalidTint = ColorFilter.mode(
    Color(0xFFE5484D),
    BlendMode.srcATop,
  );
  static const _corners = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)];

  final Paint _sprite = Paint()..filterQuality = FilterQuality.medium;

  double get _half => (grid - 1) / 2;

  /// [heights] = Säulenhöhen (Index y * grid + x) für die Schattenberechnung.
  void render(
    Canvas canvas,
    IsoProjection p,
    List<RenderCube> cubes,
    double thetaDeg,
    List<int> heights, {
    (int, int)? markerCell,
    Set<int> highlight = const {},
    Color highlightColor = const Color(0x00000000),
  }) {
    final theta = thetaDeg * math.pi / 180;
    final frame = sprites.frameFor(thetaDeg);
    final scale = p.unit / sprites.ppu;

    final still = thetaDeg % 90 == 0;
    final img = still ? sprites.platformStill : sprites.platform[frame];
    _draw(
      canvas,
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      p.projectWorld(0, 0, sprites.platformTargetZ),
      still ? scale : scale / sprites.platformFrameScale,
      _sprite,
    );

    if (markerCell != null) {
      _draw(
        canvas,
        sprites.marker,
        sprites.atlasRect(frame, sprites.tileSize),
        p.project(
          markerCell.$1 - _half,
          markerCell.$2 - _half,
          sprites.tileCenterZ,
          theta,
        ),
        scale,
        _sprite,
      );
    }

    // Schatten auf freien Plattformfeldern
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        if (heights[y * grid + x] == 0) {
          _surfaceShadow(canvas, p, x, y, 0, theta, heights, 0.5);
          if (highlight.contains(y * grid + x)) {
            canvas.drawPath(
              _surfacePath(p, x, y, 0, theta, 0.46),
              Paint()..color = highlightColor,
            );
          }
        }
      }
    }

    // Würfel von hinten nach vorne; Schatten auf einer Oberseite direkt nach ihrem Würfel
    cubes.sort((a, b) => (a.wx - a.wy + a.z).compareTo(b.wx - b.wy + b.z));
    final cell = Size(sprites.cubeSize, sprites.cubeSize);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final c in cubes) {
      paint
        ..color = Color.fromRGBO(255, 255, 255, c.opacity)
        ..colorFilter = c.invalid ? _invalidTint : null;
      final center = p.projectWorld(c.wx, c.wy, c.z);
      final src = sprites.atlasRect(c.frame, cell);
      if (c.solid && c.squash == 1) _underlay(canvas, p, c, theta);
      if (c.squash == 1) {
        _draw(canvas, sprites.cubes[c.color], src, center, scale, paint);
      } else {
        // um die Standfläche stauchen, Breite gleicht leicht aus
        final base = center.dy + 0.5 * p.unitHeight;
        final w = src.width * scale * (1 + (1 - c.squash) * 0.5),
            h = src.height * scale * c.squash;
        canvas.drawImageRect(
          sprites.cubes[c.color],
          src,
          Rect.fromCenter(
            center: Offset(center.dx, base - 0.5 * p.unitHeight * c.squash),
            width: w,
            height: h,
          ),
          paint,
        );
      }
      final t = c.shadowTop;
      if (t != null) {
        _surfaceShadow(canvas, p, t.$1, t.$2, t.$3, theta, heights, 0.47);
        if (highlight.contains(t.$2 * grid + t.$1)) {
          canvas.drawPath(
            _surfacePath(p, t.$1, t.$2, t.$3, theta, 0.44),
            Paint()..color = highlightColor,
          );
        }
      }
    }
  }

  /// Füllt die Silhouette des (ungefasten) Würfels dunkel. Dadurch erscheinen
  /// die Fugen zwischen benachbarten Würfeln als Schattenfuge, statt dass
  /// dahinterliegende Würfel durchscheinen.
  void _underlay(Canvas canvas, IsoProjection p, RenderCube c, double theta) {
    final a = c.frame == 0 ? 0.0 : theta;
    const k = 0.5;
    final pts = <(double, double)>[];
    for (final (qx, qy) in _corners) {
      final (rx, ry) = IsoProjection.rotate(qx * k, qy * k, a);
      for (final dz in const [-k, k]) {
        final o = p.projectWorld(c.wx + rx, c.wy + ry, c.z + dz);
        pts.add((o.dx, o.dy));
      }
    }
    final hull = _convexHull(pts);
    final path = Path()..moveTo(hull[0].$1, hull[0].$2);
    for (var i = 1; i < hull.length; i++) {
      path.lineTo(hull[i].$1, hull[i].$2);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = sprites.cubeShade[c.color].withValues(alpha: c.opacity),
    );
  }

  /// Kleine Vorschau eines Bausteins (für "nächster Baustein").
  void renderPiece(
    Canvas canvas,
    PieceShape shape,
    Offset center,
    double unit,
  ) {
    final p = IsoProjection(origin: center, unit: unit);
    final cx = (shape.width - 1) / 2,
        cy = (shape.depth - 1) / 2,
        cz = (shape.height - 1) / 2;
    final cells = [...shape.cells]
      ..sort((a, b) => (a.$1 - a.$2 + a.$3).compareTo(b.$1 - b.$2 + b.$3));
    final src = sprites.atlasRect(0, Size(sprites.cubeSize, sprites.cubeSize));
    for (final (x, y, z) in cells) {
      _draw(
        canvas,
        sprites.cubes[shape.color],
        src,
        p.projectWorld(x - cx, y - cy, z - cz),
        unit / sprites.ppu,
        _sprite,
      );
    }
  }

  void _draw(
    Canvas canvas,
    Image img,
    Rect src,
    Offset center,
    double scale,
    Paint paint,
  ) {
    canvas.drawImageRect(
      img,
      src,
      Rect.fromCenter(
        center: center,
        width: src.width * scale,
        height: src.height * scale,
      ),
      paint,
    );
  }

  /// Umriss der waagerechten Fläche der Zelle ([x], [y]) in Höhe [h].
  Path _surfacePath(
    IsoProjection p,
    int x,
    int y,
    int h,
    double theta,
    double halfSize,
  ) {
    final (cx, cy) = IsoProjection.rotate(x - _half, y - _half, theta);
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final (rx, ry) = IsoProjection.rotate(
        _corners[i].$1 * halfSize,
        _corners[i].$2 * halfSize,
        theta,
      );
      final o = p.projectWorld(cx + rx, cy + ry, h.toDouble());
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  /// Rahmen um den Plattformgrundriss in Höhe [z] (zeigt die Bauhöhen-Grenze).
  void renderLimitFrame(
    Canvas canvas,
    IsoProjection p,
    double z,
    double thetaDeg,
    Color color,
  ) {
    final theta = thetaDeg * math.pi / 180;
    final half = grid / 2 + 0.06;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final (rx, ry) = IsoProjection.rotate(
        _corners[i].$1 * half,
        _corners[i].$2 * half,
        theta,
      );
      final o = p.projectWorld(rx, ry, z);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, p.unit * 0.045)
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  /// Zeichnet auf die waagerechte Fläche der Zelle ([x], [y]) in Höhe [h] die
  /// Schatten aller höheren Säulen. Das Licht ist kamerafest (wie in Blender).
  void _surfaceShadow(
    Canvas canvas,
    IsoProjection p,
    int x,
    int y,
    int h,
    double theta,
    List<int> heights,
    double halfSize,
  ) {
    final sun = sprites.sunDir;
    final ox = -sun[0] / sun[2],
        oy = -sun[1] / sun[2]; // Schattenversatz je Höheneinheit
    final reach = math.sqrt(ox * ox + oy * oy);
    final (cx, cy) = IsoProjection.rotate(x - _half, y - _half, theta);
    Path? shadow;
    for (var b = 0; b < grid; b++) {
      for (var a = 0; a < grid; a++) {
        final dh = heights[b * grid + a] - h;
        if (dh <= 0 || (a == x && b == y)) continue;
        final (sx, sy) = IsoProjection.rotate(a - _half, b - _half, theta);
        final ddx = cx - sx, ddy = cy - sy;
        if (ddx * ddx + ddy * ddy > (dh * reach + 1.5) * (dh * reach + 1.5)) {
          continue;
        }
        final pts = <(double, double)>[];
        for (final (qx, qy) in _corners) {
          final (rx, ry) = IsoProjection.rotate(qx * 0.5, qy * 0.5, theta);
          pts.add((sx + rx, sy + ry));
          pts.add((sx + rx + ox * dh, sy + ry + oy * dh));
        }
        final hull = _convexHull(pts);
        shadow ??= Path();
        for (var i = 0; i < hull.length; i++) {
          final o = p.projectWorld(hull[i].$1, hull[i].$2, h.toDouble());
          i == 0 ? shadow.moveTo(o.dx, o.dy) : shadow.lineTo(o.dx, o.dy);
        }
        shadow.close();
      }
    }
    if (shadow == null) return;
    final clip = _surfacePath(p, x, y, h, theta, halfSize);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawPath(
      shadow,
      Paint()
        ..color = _shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.unit * 0.045),
    );
    canvas.restore();
  }

  static List<(double, double)> _convexHull(List<(double, double)> pts) {
    final s = [...pts]
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    double cross((double, double) o, (double, double) a, (double, double) b) =>
        (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
    final h = <(double, double)>[];
    for (final q in s) {
      while (h.length >= 2 && cross(h[h.length - 2], h.last, q) <= 0) {
        h.removeLast();
      }
      h.add(q);
    }
    final t = h.length + 1;
    for (final q in s.reversed) {
      while (h.length >= t && cross(h[h.length - 2], h.last, q) <= 0) {
        h.removeLast();
      }
      h.add(q);
    }
    h.removeLast();
    return h;
  }
}
