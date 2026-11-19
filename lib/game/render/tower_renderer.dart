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
    this.cell,
    this.solid = true,
    this.slot,
    this.cameraFixed = false,
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

  /// Plattformzelle (x, y, z) eines fest liegenden Würfels. Nur dann werden
  /// Schatten und Eck-Schattierung auf seinen Flächen gezeichnet.
  final (int, int, int)? cell;

  /// Fugen zu Nachbarwürfeln füllen (für feste Würfel, nicht für die Vorschau).
  final bool solid;

  /// Rasterplatz (Gruppe, x, y, z), über den Nachbarn erkannt werden. Würfel
  /// derselben Gruppe mit benachbartem Platz gelten als aneinanderliegend.
  final (int, int, int, int)? slot;

  /// Der Würfel dreht sich nicht mit der Plattform (schwebender Baustein).
  final bool cameraFixed;
}

/// Zeichnet Plattform, Schatten und Würfel für einen beliebigen Drehwinkel
/// (Sprite-Komposition). Kennt keinen Spielzustand.
class TowerRenderer {
  TowerRenderer(this.sprites, {this.grid = 5});

  final SpriteSet sprites;
  final int grid;

  static const _shadowColor = Color(0x52101820);
  static const _aoColor = Color(0xFF101820);
  static const _aoClear = Color(0x00101820);
  static const _corners = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)];
  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  final Paint _sprite = Paint()..filterQuality = FilterQuality.medium;
  final Paint _platformPaint = Paint()..filterQuality = FilterQuality.medium;

  /// Umfärbung der Plattform (kosmetische Freischaltung), `null` = Original.
  set platformFilter(ColorFilter? f) => _platformPaint.colorFilter = f;
  final Paint _cubePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _glossPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _fill = Paint();

  double get _half => (grid - 1) / 2;

  int _h(List<int> heights, int x, int y) =>
      x < 0 || y < 0 || x >= grid || y >= grid ? -1 : heights[y * grid + x];

  /// [heights] = Säulenhöhen (Index y * grid + x) für Schatten.
  /// [markerCorner] = Ecke (±1, ±1) der Plattform mit Orientierungsmarke.
  void render(
    Canvas canvas,
    IsoProjection p,
    List<RenderCube> cubes,
    double thetaDeg,
    List<int> heights, {
    (int, int)? markerCorner,
    Set<int> highlight = const {},
    Color highlightColor = const Color(0x00000000),
  }) {
    final theta = thetaDeg * math.pi / 180;
    final frame = sprites.frameFor(thetaDeg);
    final scale = p.unit / sprites.ppu;

    // Eckpfosten: je nach Lage hinter der Plattform, davor oder vor allem
    double pegX = 0, pegY = 0, pegDepth = 0;
    if (markerCorner != null) {
      (pegX, pegY) = IsoProjection.rotate(
        markerCorner.$1 * sprites.pegOffset,
        markerCorner.$2 * sprites.pegOffset,
        theta,
      );
      pegDepth = pegX - pegY;
    }
    void drawPeg() => _draw(
      canvas,
      sprites.peg,
      Rect.fromLTWH(
        0,
        0,
        sprites.peg.width.toDouble(),
        sprites.peg.height.toDouble(),
      ),
      p.projectWorld(pegX, pegY, sprites.pegCenterZ),
      scale,
      _sprite,
    );
    if (markerCorner != null && pegDepth < -1) drawPeg();

    final still = thetaDeg % 90 == 0;
    final img = still ? sprites.platformStill : sprites.platform[frame];
    _draw(
      canvas,
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      p.projectWorld(0, 0, sprites.platformTargetZ),
      still ? scale : scale / sprites.platformFrameScale,
      _platformPaint,
    );

    if (markerCorner != null) {
      final mx = markerCorner.$1 < 0 ? 0 : grid - 1,
          my = markerCorner.$2 < 0 ? 0 : grid - 1;
      _draw(
        canvas,
        sprites.marker,
        sprites.atlasRect(frame, sprites.tileSize),
        p.project(mx - _half, my - _half, sprites.tileCenterZ, theta),
        scale,
        _sprite,
      );
      if (pegDepth >= -1 && pegDepth <= 1) drawPeg();
    }

    // Freie Plattformfelder: Schatten, Eck-Schattierung, Hervorhebung
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        if (heights[y * grid + x] != 0) continue;
        _surfaceShadow(canvas, p, x, y, 0, theta, heights, 0.5);
        _topOcclusion(canvas, p, x, y, 0, theta, heights);
        if (highlight.contains(y * grid + x)) {
          canvas.drawPath(
            _surfacePath(p, x, y, 0, theta, 0.46),
            _fill..color = highlightColor,
          );
        }
      }
    }

    // Würfel von hinten nach vorne; Flächen-Effekte direkt nach ihrem Würfel
    cubes.sort((a, b) => (a.wx - a.wy + a.z).compareTo(b.wx - b.wy + b.z));
    final cellSize = Size(sprites.cubeSize, sprites.cubeSize);
    final gloss = sprites.gloss;
    _slots.clear();
    if (sprites.edgeInset > 0) {
      for (final c in cubes) {
        final s = c.slot;
        if (s != null && c.solid) _slots.add(_slotKey(s.$1, s.$2, s.$3, s.$4));
      }
    }
    for (final c in cubes) {
      _cubePaint
        ..color = Color.fromRGBO(255, 255, 255, c.opacity)
        ..colorFilter = c.invalid ? sprites.invalidTint : sprites.tint[c.color];
      final center = p.projectWorld(c.wx, c.wy, c.z);
      final src = sprites.atlasRect(c.frame, cellSize);
      if (c.solid && c.squash == 1) _underlay(canvas, p, c, theta);
      if (c.squash == 1) {
        _draw(canvas, sprites.cube, src, center, scale, _cubePaint);
        if (gloss != null && !c.invalid) {
          _glossPaint.color = Color.fromRGBO(255, 255, 255, c.opacity);
          _draw(canvas, gloss, src, center, scale, _glossPaint);
        }
      } else {
        // um die Standfläche stauchen, Breite gleicht leicht aus
        final base = center.dy + 0.5 * p.unitHeight;
        canvas.drawImageRect(
          sprites.cube,
          src,
          Rect.fromCenter(
            center: Offset(center.dx, base - 0.5 * p.unitHeight * c.squash),
            width: src.width * scale * (1 + (1 - c.squash) * 0.5),
            height: src.height * scale * c.squash,
          ),
          _cubePaint,
        );
      }
      final cell = c.cell;
      if (cell == null) continue;
      final (x, y, z) = cell;
      _sideOcclusion(canvas, p, x, y, z, theta, heights);
      if (heights[y * grid + x] == z + 1) {
        _surfaceShadow(canvas, p, x, y, z + 1, theta, heights, 0.47);
        _topOcclusion(canvas, p, x, y, z + 1, theta, heights);
        if (highlight.contains(y * grid + x)) {
          canvas.drawPath(
            _surfacePath(p, x, y, z + 1, theta, 0.44),
            _fill..color = highlightColor,
          );
        }
      }
    }

    if (markerCorner != null && pegDepth > 1) drawPeg();
  }

  final Set<int> _slots = {};

  static int _slotKey(int g, int x, int y, int z) =>
      g + 4 * ((x + 8) + 32 * ((y + 8) + 32 * (z + 8)));

  /// Füllt die Silhouette des Würfels im leicht abgedunkelten Eigenton.
  /// Dadurch erscheinen die Fugen zwischen benachbarten Würfeln als weiche
  /// Falze, statt dass dahinterliegende Würfel durchscheinen.
  ///
  /// Bei Materialien mit stark gebrochenen Kanten ([SpriteSet.edgeInset] > 0)
  /// wird die Füllung an jeder Kante zurückgenommen, an der kein Nachbar
  /// anliegt. Sonst stünde sie als Rand um den Würfel und würde seine Form
  /// verdecken.
  void _underlay(Canvas canvas, IsoProjection p, RenderCube c, double theta) {
    final a = c.frame == 0 ? 0.0 : theta;
    const k = 0.5;
    final r = sprites.edgeInset;
    final pts = <(double, double)>[];
    void add(double lx, double ly, double lz) {
      final (rx, ry) = IsoProjection.rotate(lx, ly, a);
      final o = p.projectWorld(c.wx + rx, c.wy + ry, c.z + lz);
      pts.add((o.dx, o.dy));
    }

    if (r <= 0) {
      for (final (qx, qy) in _corners) {
        add(qx * k, qy * k, -k);
        add(qx * k, qy * k, k);
      }
    } else {
      // Nachbar in Richtung der lokalen Achse (0 = x, 1 = y, 2 = z)?
      final slot = c.slot;
      final turn = c.cameraFixed ? a : a - theta;
      bool neighbour(int axis, int sign) {
        if (slot == null) return false;
        var dx = 0, dy = 0, dz = 0;
        if (axis == 2) {
          dz = sign;
        } else {
          final (vx, vy) = IsoProjection.rotate(
            axis == 0 ? sign.toDouble() : 0,
            axis == 1 ? sign.toDouble() : 0,
            turn,
          );
          dx = vx.round();
          dy = vy.round();
        }
        return _slots.contains(
          _slotKey(slot.$1, slot.$2 + dx, slot.$3 + dy, slot.$4 + dz),
        );
      }

      final has = [
        for (var axis = 0; axis < 3; axis++)
          [neighbour(axis, -1), neighbour(axis, 1)],
      ];
      void fill() {
        final hull = _convexHull(pts);
        final path = Path()..moveTo(hull[0].$1, hull[0].$2);
        for (var i = 1; i < hull.length; i++) {
          path.lineTo(hull[i].$1, hull[i].$2);
        }
        path.close();
        canvas.drawPath(
          path,
          _fill..color = sprites.shade[c.color].withValues(alpha: c.opacity),
        );
        pts.clear();
      }

      void put(int a0, double va, int a1, double vb, int a2, double vc) {
        final v = [0.0, 0.0, 0.0];
        v[a0] = va;
        v[a1] = vb;
        v[a2] = vc;
        add(v[0], v[1], v[2]);
      }

      // 1. Der Würfel mit zurückgenommenen Kanten: liegt ganz hinter dem
      //    Sprite und schliesst nur dessen weiche Ränder.
      final q = k - r - 0.015;
      for (var along = 0; along < 3; along++) {
        final b = (along + 1) % 3, cAxis = (along + 2) % 3;
        for (final e in const [-1, 1]) {
          for (final sb in const [-1, 1]) {
            for (final sc in const [-1, 1]) {
              put(along, e * k, b, sb * q, cAxis, sc * q);
            }
          }
        }
      }
      fill();
      // 2. Je anliegendem Nachbarn eine flache Scheibe an der gemeinsamen
      //    Fläche. Sie reicht nur dort bis zur vollen Kante, wo auch quer dazu
      //    ein Nachbar anliegt, und füllt so die Lücke, an der mehrere Würfel
      //    zusammenstossen. An freien Kanten bleibt die Form des Würfels frei.
      for (var axis = 0; axis < 3; axis++) {
        final b = (axis + 1) % 3, cAxis = (axis + 2) % 3;
        for (final sign in const [-1, 1]) {
          if (!has[axis][sign < 0 ? 0 : 1]) continue;
          final eb = [has[b][0] ? k : q, has[b][1] ? k : q];
          final ec = [has[cAxis][0] ? k : q, has[cAxis][1] ? k : q];
          if (eb[0] == q && eb[1] == q && ec[0] == q && ec[1] == q) continue;
          for (final depth in [k, k - r]) {
            for (final ib in const [0, 1]) {
              for (final ic in const [0, 1]) {
                put(
                  axis,
                  sign * depth,
                  b,
                  (ib == 0 ? -1 : 1) * eb[ib],
                  cAxis,
                  (ic == 0 ? -1 : 1) * ec[ic],
                );
              }
            }
          }
          fill();
        }
      }
      return;
    }
    final hull = _convexHull(pts);
    final path = Path()..moveTo(hull[0].$1, hull[0].$2);
    for (var i = 1; i < hull.length; i++) {
      path.lineTo(hull[i].$1, hull[i].$2);
    }
    path.close();
    canvas.drawPath(
      path,
      _fill..color = sprites.shade[c.color].withValues(alpha: c.opacity),
    );
  }

  /// Kleine Darstellung eines Bausteins (nächster Baustein, Ergebnis).
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
    _cubePaint
      ..color = const Color(0xFFFFFFFF)
      ..colorFilter = sprites.tint[shape.color];
    for (final (x, y, z) in cells) {
      _draw(
        canvas,
        sprites.cube,
        src,
        p.projectWorld(x - cx, y - cy, z - cz),
        unit / sprites.ppu,
        _cubePaint,
      );
      final gloss = sprites.gloss;
      if (gloss != null) {
        _glossPaint.color = const Color(0xFFFFFFFF);
        _draw(
          canvas,
          gloss,
          src,
          p.projectWorld(x - cx, y - cy, z - cz),
          unit / sprites.ppu,
          _glossPaint,
        );
      }
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

  /// Weicher Schatten der ganzen Plattform auf dem Untergrund.
  void renderGroundShadow(
    Canvas canvas,
    IsoProjection p,
    double thetaDeg,
    Color color,
  ) {
    final theta = thetaDeg * math.pi / 180;
    final half = grid / 2 + 0.3;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final (rx, ry) = IsoProjection.rotate(
        _corners[i].$1 * half,
        _corners[i].$2 * half,
        theta,
      );
      final o = p.projectWorld(rx - 0.25, ry + 0.45, -1.15);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.unit * 0.35),
    );
  }

  /// Verlauf von einer Kante in die Fläche hinein (Schattierung in Ecken).
  void _strip(
    Canvas canvas,
    IsoProjection p,
    (double, double, double) a,
    (double, double, double) b,
    (double, double, double) inward,
    double alpha,
  ) {
    final a0 = p.projectWorld(a.$1, a.$2, a.$3),
        b0 = p.projectWorld(b.$1, b.$2, b.$3);
    final a1 = p.projectWorld(
      a.$1 + inward.$1,
      a.$2 + inward.$2,
      a.$3 + inward.$3,
    );
    final b1 = p.projectWorld(
      b.$1 + inward.$1,
      b.$2 + inward.$2,
      b.$3 + inward.$3,
    );
    final path = Path()
      ..moveTo(a0.dx, a0.dy)
      ..lineTo(b0.dx, b0.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(a1.dx, a1.dy)
      ..close();
    final m0 = (a0 + b0) / 2, m1 = (a1 + b1) / 2;
    // Verlaufsrichtung senkrecht zur Kante (auch bei schräger Projektion)
    final e = b0 - a0;
    final len2 = e.dx * e.dx + e.dy * e.dy;
    if (len2 < 1e-6) return;
    final v = m1 - m0;
    final t = (v.dx * e.dx + v.dy * e.dy) / len2;
    final end = m1 - e * t;
    canvas.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(m0, end, [
          _aoColor.withValues(alpha: alpha),
          _aoClear,
        ]),
    );
  }

  /// Schattierung auf einer waagerechten Fläche entlang höherer Nachbarwände.
  void _topOcclusion(
    Canvas canvas,
    IsoProjection p,
    int x,
    int y,
    int h,
    double theta,
    List<int> heights,
  ) {
    const w = 0.30;
    final (cx, cy) = IsoProjection.rotate(x - _half, y - _half, theta);
    for (final (dx, dy) in _dirs) {
      if (_h(heights, x + dx, y + dy) <= h) continue;
      final (ex, ey) = IsoProjection.rotate(dx * 0.5, dy * 0.5, theta);
      final (px, py) = IsoProjection.rotate(-dy * 0.5, dx * 0.5, theta);
      _strip(
        canvas,
        p,
        (cx + ex + px, cy + ey + py, h.toDouble()),
        (cx + ex - px, cy + ey - py, h.toDouble()),
        (-ex * 2 * w, -ey * 2 * w, 0),
        0.26,
      );
    }
  }

  /// Schattierung am Fuss sichtbarer Seitenflächen, wo eine Fläche anschliesst.
  void _sideOcclusion(
    Canvas canvas,
    IsoProjection p,
    int x,
    int y,
    int z,
    double theta,
    List<int> heights,
  ) {
    const w = 0.34;
    final (cx, cy) = IsoProjection.rotate(x - _half, y - _half, theta);
    for (final (dx, dy) in _dirs) {
      // nur wenn direkt am Fuss dieser Seite eine Fläche liegt
      if (_h(heights, x + dx, y + dy) != z) continue;
      final (ex, ey) = IsoProjection.rotate(dx * 0.5, dy * 0.5, theta);
      if (ex - ey < 0.05) continue; // Seite zeigt von der Kamera weg
      final (px, py) = IsoProjection.rotate(-dy * 0.5, dx * 0.5, theta);
      _strip(
        canvas,
        p,
        (cx + ex + px, cy + ey + py, z.toDouble()),
        (cx + ex - px, cy + ey - py, z.toDouble()),
        (0, 0, w),
        0.22,
      );
    }
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
        final r = dh * reach + 1.5;
        if (ddx * ddx + ddy * ddy > r * r) continue;
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
    canvas.save();
    canvas.clipPath(_surfacePath(p, x, y, h, theta, halfSize));
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
