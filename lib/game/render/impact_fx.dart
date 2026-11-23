import 'dart:math' as math;
import 'dart:ui';

import '../projection/iso_projection.dart';

/// Gewählter Effekt aus dem Shop.
enum FxStyle { dust, confetti, shards }

enum _Kind { puff, speck, paper, shard, spark }

class _Part {
  _Part(
    this.kind,
    this.x,
    this.y,
    this.z,
    this.vx,
    this.vy,
    this.vz,
    this.life,
    this.size,
    this.color, {
    this.gravity = 0,
    this.drag = 0,
    this.floor = double.negativeInfinity,
    this.spin = 0,
    this.phase = 0,
    this.delay = 0,
  });

  final _Kind kind;
  double x, y, z, vx, vy, vz;
  final double life, size, gravity, drag, floor, spin, phase;

  /// Wartezeit bis zum Start (für gestaffelte Ausbrüche).
  double delay;
  final Color color;
  double age = 0;
  bool bounced = false;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// Flacher Ring, der sich in der Ebene z ausbreitet.
class _Ring {
  _Ring(
    this.x,
    this.y,
    this.z,
    this.from,
    this.to,
    this.life,
    this.color,
    this.width, {
    this.delay = 0,
    this.square = false,
  });
  final double x, y, z, from, to, life, width;
  final Color color;

  /// Quadratisch wie die Plattform statt rund.
  final bool square;
  double delay;
  double age = 0;
}

/// Kurzes Aufleuchten der Oberseite eines Würfels.
class _Flash {
  _Flash(this.x, this.y, this.z, this.life, this.strength);
  final double x, y, z, life, strength;
  double age = 0;
}

/// Alles, was beim Ablegen fliegt, leuchtet und sich ausbreitet: Staub,
/// Konfetti oder Splitter, Druckwellen, das Aufblitzen der Oberseiten und die
/// Feier einer vollen Ebene oder Etappe.
///
/// Gerechnet wird in Plattformkoordinaten (Mitte = 0, eine Einheit je Würfel),
/// die Teilchen drehen sich also mit der Plattform mit. Rein optisch: nichts
/// hier beeinflusst das Spiel.
class ImpactFx {
  ImpactFx([math.Random? rng]) : _rng = rng ?? math.Random();

  final math.Random _rng;
  final List<_Part> _parts = [];
  final List<_Ring> _rings = [];
  final List<_Flash> _flashes = [];

  FxStyle style = FxStyle.dust;

  /// Helles Aufblitzen des ganzen Bildes (0 = aus), klingt von selbst ab.
  double screenFlash = 0;

  /// Obergrenze, damit lange Serien die Bildrate nicht drücken.
  static const maxParts = 260;

  static const _white = Color(0xFFFFFFFF);
  static const _cream = Color(0xFFFFFAF0);
  static const _mint = Color(0xFF35B6A4);
  static const _amber = Color(0xFFF1BD58);
  static const _dustRim = Color(0xFF8C7A62);

  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();

  bool get isIdle =>
      _parts.isEmpty && _rings.isEmpty && _flashes.isEmpty && screenFlash <= 0;

  void clear() {
    _parts.clear();
    _rings.clear();
    _flashes.clear();
    screenFlash = 0;
  }

  double _r(double a, double b) => a + _rng.nextDouble() * (b - a);

  void _add(_Part p) {
    if (_parts.length >= maxParts) _parts.removeAt(0);
    _parts.add(p);
  }

  // ------------------------------------------------------------ Auslöser

  /// Ab dieser Combo kommen Sterne und die zweite Welle dazu.
  static const warmCombo = 3;

  /// Ab dieser Combo fliegt der gewählte Effekt aus dem Shop.
  static const hotCombo = 5;

  /// Ein Baustein ist gelandet. [cells] sind seine Würfel in
  /// Plattformkoordinaten, [force] 0..1 wächst mit Fallhöhe und Größe.
  ///
  /// Die Stärke richtet sich nach der Combo: darunter bleibt es bei einer
  /// Druckwelle und etwas Staub, ab [warmCombo] kommen Sterne dazu, ab
  /// [hotCombo] der Effekt aus dem Shop, der bis Combo 12 weiter zunimmt.
  void landing({
    required List<(double, double, int)> cells,
    required Color color,
    required List<Color> palette,
    required double force,
    required bool clean,
    int combo = 0,
  }) {
    if (cells.isEmpty) return;
    var cx = 0.0, cy = 0.0, bottom = 1 << 20;
    for (final (x, y, z) in cells) {
      cx += x;
      cy += y;
      bottom = math.min(bottom, z);
    }
    cx /= cells.length;
    cy /= cells.length;
    final base = bottom.toDouble();
    final warm = combo >= warmCombo;
    final hot = combo >= hotCombo;
    // 0 bei Combo 5, 1 ab Combo 12
    final heat = ((combo - hotCombo) / 7).clamp(0.0, 1.0);
    final boost = 0.6 + 0.9 * heat;
    final columns = <(double, double), int>{};
    for (final (x, y, z) in cells) {
      columns[(x, y)] = math.max(columns[(x, y)] ?? z, z);
    }

    // Oberseiten leuchten kurz auf.
    columns.forEach((xy, z) {
      _flashes.add(_Flash(xy.$1, xy.$2, z + 1.0, 0.2, hot ? 0.55 : 0.28));
    });

    // Druckwelle am Fuß; sauber abgelegt in Mint und kräftiger.
    final reach = 0.9 + 0.35 * math.sqrt(cells.length);
    _rings.add(
      _Ring(
        cx,
        cy,
        base + 0.04,
        reach * 0.45,
        reach * (1.2 + 0.4 * force + 0.3 * heat),
        0.34,
        clean ? _mint : _white,
        hot ? 0.075 : 0.05,
      ),
    );
    if (clean && warm) {
      _rings.add(
        _Ring(
          cx,
          cy,
          base + 0.04,
          reach * 0.3,
          reach * (0.95 + 0.4 * force),
          0.42,
          _white,
          0.04,
          delay: 0.06,
        ),
      );
      for (var i = 0; i < 3; i++) {
        _spark(cx + _r(-0.9, 0.9), cy + _r(-0.9, 0.9), base + _r(0.9, 1.7));
      }
    }

    // Staub quillt immer am Fuß hervor: er gibt dem Stein Gewicht.
    final puffs = hot && style == FxStyle.dust ? 6 : 2;
    for (final (x, y, z) in cells) {
      if (z != bottom) continue;
      for (var i = 0; i < (puffs * (0.6 + 0.6 * force)).round(); i++) {
        final a = _r(0, math.pi * 2);
        final v = _r(1.0, 2.4) * (0.7 + 0.6 * force);
        _add(
          _Part(
            _Kind.puff,
            x + math.cos(a) * 0.46,
            y + math.sin(a) * 0.46,
            base + 0.05,
            math.cos(a) * v,
            math.sin(a) * v,
            _r(0.15, 0.55),
            _r(0.45, 0.75),
            _r(0.12, 0.22),
            _cream,
            drag: 4.5,
          ),
        );
      }
    }

    if (!hot) return;
    switch (style) {
      case FxStyle.dust:
        // Ein paar Krümel springen hoch und fallen zurück.
        for (var i = 0; i < (5 + cells.length * 2) * boost; i++) {
          final a = _r(0, math.pi * 2);
          final v = _r(0.8, 2.2);
          _add(
            _Part(
              _Kind.speck,
              cx + math.cos(a) * 0.5,
              cy + math.sin(a) * 0.5,
              base + 0.1,
              math.cos(a) * v,
              math.sin(a) * v,
              _r(1.8, 4.2) * (0.7 + 0.5 * force),
              _r(0.45, 0.75),
              _r(0.04, 0.07),
              _cream,
              gravity: 13,
              floor: base,
            ),
          );
        }
      case FxStyle.confetti:
        final n = ((8 + cells.length * 4) * boost).round();
        for (var i = 0; i < n; i++) {
          final (x, y, z) = cells[i % cells.length];
          _paper(
            x + _r(-0.4, 0.4),
            y + _r(-0.4, 0.4),
            z + 1.0,
            palette[_rng.nextInt(palette.length)],
            up: _r(3.6, 6.6) * (0.8 + 0.3 * force),
            out: _r(0.5, 2.3),
          );
        }
      case FxStyle.shards:
        final n = ((7 + cells.length * 3) * boost).round();
        for (var i = 0; i < n; i++) {
          final (x, y, _) = cells[i % cells.length];
          _shard(
            x,
            y,
            base + 0.15,
            color,
            i,
            out: _r(1.6, 3.8) * (0.8 + 0.3 * force),
            up: _r(2.2, 5.2),
            floor: base,
          );
        }
        for (var i = 0; i < 2; i++) {
          _spark(cx + _r(-0.7, 0.7), cy + _r(-0.7, 0.7), base + _r(0.6, 1.4));
        }
    }
  }

  /// Eine Ebene ist vollständig: Rahmen leuchtet, Wellen laufen nach außen,
  /// am Rand fliegt der gewählte Effekt weg.
  void layer(int z, double half, List<Color> palette, Color color) {
    final top = z + 1.0;
    screenFlash = math.max(screenFlash, 0.16);
    for (final (delay, colorOf, width) in [
      (0.0, _white, 0.11),
      (0.08, _mint, 0.08),
      (0.18, _white, 0.05),
    ]) {
      _rings.add(
        _Ring(
          0,
          0,
          top,
          half,
          half * 1.55,
          0.55,
          colorOf,
          width,
          delay: delay,
          square: true,
        ),
      );
    }
    // Funken wandern einmal um den Rand der Ebene.
    const perSide = 6;
    for (var side = 0; side < 4; side++) {
      for (var i = 0; i < perSide; i++) {
        final u = -half + (i + 0.5) / perSide * half * 2;
        final (x, y, nx, ny) = switch (side) {
          0 => (u, -half, 0.0, -1.0),
          1 => (half, u, 1.0, 0.0),
          2 => (-u, half, 0.0, 1.0),
          _ => (-half, -u, -1.0, 0.0),
        };
        final delay = (side * perSide + i) / (perSide * 4) * 0.22;
        switch (style) {
          case FxStyle.dust:
            _add(
              _Part(
                _Kind.puff,
                x,
                y,
                top - 0.5,
                nx * _r(1.6, 3.0),
                ny * _r(1.6, 3.0),
                _r(0.2, 0.9),
                _r(0.5, 0.8),
                _r(0.11, 0.2),
                _cream,
                drag: 3.6,
                delay: delay,
              ),
            );
            if (i.isEven) _spark(x + nx * 0.3, y + ny * 0.3, top, delay: delay);
          case FxStyle.confetti:
            _paper(
              x,
              y,
              top,
              palette[_rng.nextInt(palette.length)],
              up: _r(3.5, 6.5),
              out: _r(1.2, 2.8),
              dirX: nx,
              dirY: ny,
              delay: delay,
            );
          case FxStyle.shards:
            _shard(
              x,
              y,
              top - 0.2,
              i.isEven ? color : palette[_rng.nextInt(palette.length)],
              i,
              out: _r(2.0, 4.2),
              up: _r(2.5, 5.5),
              floor: double.negativeInfinity,
              dirX: nx,
              dirY: ny,
              delay: delay,
            );
        }
      }
    }
  }

  /// Etappe oder Höhenmarke erreicht: eine Fontäne von der Turmspitze.
  /// [level] 1 = Höhenmarke, 2 = Etappe.
  void celebrate(double z, int level, List<Color> palette) {
    screenFlash = math.max(screenFlash, level > 1 ? 0.22 : 0.12);
    for (var i = 0; i < level + 1; i++) {
      _rings.add(
        _Ring(
          0,
          0,
          z,
          0.6,
          2.6 + level * 1.2,
          0.6,
          i.isEven ? _amber : _white,
          0.09 - i * 0.02,
          delay: i * 0.1,
        ),
      );
    }
    final n = level > 1 ? 54 : 30;
    for (var i = 0; i < n; i++) {
      final delay = _r(0, level > 1 ? 0.35 : 0.2);
      final c = palette[_rng.nextInt(palette.length)];
      if (style == FxStyle.shards) {
        _shard(
          _r(-0.8, 0.8),
          _r(-0.8, 0.8),
          z + 0.2,
          c,
          i,
          out: _r(1.0, 3.6),
          up: _r(4.5, 8.5),
          floor: double.negativeInfinity,
          delay: delay,
        );
      } else {
        // Auch der Staub feiert mit bunten Schnipseln: eine Etappe ist selten.
        _paper(
          _r(-0.8, 0.8),
          _r(-0.8, 0.8),
          z + 0.2,
          c,
          up: _r(5.0, 9.0),
          out: _r(0.6, 3.2),
          delay: delay,
        );
      }
    }
    for (var i = 0; i < 6; i++) {
      _spark(_r(-1.8, 1.8), _r(-1.8, 1.8), z + _r(0.6, 2.6), delay: _r(0, 0.4));
    }
  }

  /// Zeigt den gewählten Effekt einmal auf der Shop-Bühne.
  void preview(double z, List<Color> palette) {
    landing(
      cells: [
        for (final (x, y) in const [(-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5)])
          (x, y, z.round()),
      ],
      color: palette[_rng.nextInt(palette.length)],
      palette: palette,
      force: 1,
      clean: true,
      combo: 9,
    );
  }

  void _paper(
    double x,
    double y,
    double z,
    Color color, {
    required double up,
    required double out,
    double? dirX,
    double? dirY,
    double delay = 0,
  }) {
    var dx = dirX, dy = dirY;
    if (dx == null || dy == null) {
      final a = _r(0, math.pi * 2);
      dx = math.cos(a);
      dy = math.sin(a);
    } else {
      // etwas streuen
      dx += _r(-0.45, 0.45);
      dy += _r(-0.45, 0.45);
    }
    _add(
      _Part(
        _Kind.paper,
        x,
        y,
        z,
        dx * out,
        dy * out,
        up,
        _r(0.95, 1.5),
        _r(0.13, 0.21),
        color,
        gravity: 9.5,
        drag: 1.3,
        spin: _r(-7, 7),
        phase: _r(0, 6.28),
        delay: delay,
      ),
    );
  }

  void _shard(
    double x,
    double y,
    double z,
    Color color,
    int i, {
    required double out,
    required double up,
    required double floor,
    double? dirX,
    double? dirY,
    double delay = 0,
  }) {
    var dx = dirX, dy = dirY;
    if (dx == null || dy == null) {
      final a = _r(0, math.pi * 2);
      dx = math.cos(a);
      dy = math.sin(a);
    } else {
      dx += _r(-0.4, 0.4);
      dy += _r(-0.4, 0.4);
    }
    // Abwechselnd heller und dunkler, wie Bruchkanten.
    final shade = switch (i % 3) {
      0 => Color.lerp(color, _white, 0.35)!,
      1 => color,
      _ => Color.lerp(color, const Color(0xFF000000), 0.18)!,
    };
    _add(
      _Part(
        _Kind.shard,
        x + dx * 0.45,
        y + dy * 0.45,
        z,
        dx * out,
        dy * out,
        up,
        _r(0.7, 1.1),
        _r(0.14, 0.25),
        shade,
        gravity: 14,
        floor: floor,
        spin: _r(-11, 11),
        phase: _r(0, 6.28),
        delay: delay,
      ),
    );
  }

  void _spark(double x, double y, double z, {double delay = 0}) {
    _add(
      _Part(
        _Kind.spark,
        x,
        y,
        z,
        0,
        0,
        0.5,
        _r(0.32, 0.5),
        _r(0.13, 0.22),
        _white,
        delay: delay,
      ),
    );
  }

  // -------------------------------------------------------------- Ablauf

  void update(double dt) {
    if (screenFlash > 0) screenFlash = math.max(0, screenFlash - dt * 0.9);
    for (final p in _parts) {
      if (p.delay > 0) {
        p.delay -= dt;
        continue;
      }
      p.age += dt;
      p.vz -= p.gravity * dt;
      if (p.drag > 0) {
        final k = math.exp(-p.drag * dt);
        p.vx *= k;
        p.vy *= k;
        if (p.gravity == 0) p.vz *= k;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      // Einmal aufspringen, dann liegen bleiben.
      if (p.z < p.floor) {
        p.z = p.floor;
        if (!p.bounced && p.vz < -1.2) {
          p.bounced = true;
          p.vz = -p.vz * 0.38;
          p.vx *= 0.6;
          p.vy *= 0.6;
        } else {
          p.vz = 0;
          p.vx *= 0.8;
          p.vy *= 0.8;
        }
      }
    }
    _parts.removeWhere((p) => p.age >= p.life);
    for (final r in _rings) {
      r.delay > 0 ? r.delay -= dt : r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= r.life);
    for (final f in _flashes) {
      f.age += dt;
    }
    _flashes.removeWhere((f) => f.age >= f.life);
  }

  // ----------------------------------------------------------- Zeichnen

  /// Aufleuchtende Oberseiten und Wellen; liegt über den Würfeln, aber unter
  /// den Teilchen.
  void render(Canvas canvas, IsoProjection proj, double theta) {
    final unit = proj.unit;

    for (final f in _flashes) {
      final k = 1 - f.age / f.life;
      _path.reset();
      const h = 0.47;
      for (final (i, (dx, dy)) in const [
        (-h, -h),
        (h, -h),
        (h, h),
        (-h, h),
      ].indexed) {
        final o = proj.project(f.x + dx, f.y + dy, f.z, theta);
        i == 0 ? _path.moveTo(o.dx, o.dy) : _path.lineTo(o.dx, o.dy);
      }
      _path.close();
      _fill.color = _white.withValues(alpha: f.strength * k * k);
      canvas.drawPath(_path, _fill);
    }

    for (final r in _rings) {
      if (r.delay > 0) continue;
      final t = r.age / r.life;
      final e = 1 - math.pow(1 - t, 3).toDouble(); // schnell los, weich aus
      final radius = r.from + (r.to - r.from) * e;
      _path.reset();
      if (r.square) {
        for (final (i, (sx, sy)) in const [
          (-1.0, -1.0),
          (1.0, -1.0),
          (1.0, 1.0),
          (-1.0, 1.0),
        ].indexed) {
          final o = proj.project(
            r.x + sx * radius,
            r.y + sy * radius,
            r.z,
            theta,
          );
          i == 0 ? _path.moveTo(o.dx, o.dy) : _path.lineTo(o.dx, o.dy);
        }
      } else {
        const steps = 30;
        for (var i = 0; i < steps; i++) {
          final a = i / steps * math.pi * 2;
          final o = proj.project(
            r.x + math.cos(a) * radius,
            r.y + math.sin(a) * radius,
            r.z,
            theta,
          );
          i == 0 ? _path.moveTo(o.dx, o.dy) : _path.lineTo(o.dx, o.dy);
        }
      }
      _path.close();
      _stroke
        ..color = r.color.withValues(alpha: 0.9 * (1 - t) * (1 - t))
        ..strokeWidth = math.max(1, r.width * unit * (1 - 0.6 * t));
      canvas.drawPath(_path, _stroke);
    }

    for (final p in _parts) {
      if (p.delay > 0) continue;
      final o = proj.project(p.x, p.y, p.z, theta);
      final t = p.t;
      switch (p.kind) {
        case _Kind.puff:
          final radius = p.size * unit * (0.55 + 1.5 * t);
          final fade = (1 - t) * (1 - t);
          // Dunklerer Saum: so hebt sich der Staub auch von hellem Grund ab.
          _fill.color = _dustRim.withValues(alpha: 0.2 * fade);
          canvas.drawCircle(
            o.translate(0, radius * 0.14),
            radius * 1.12,
            _fill,
          );
          _fill.color = p.color.withValues(alpha: 0.78 * fade);
          canvas.drawCircle(o, radius, _fill);
        case _Kind.speck:
          _fill.color = p.color.withValues(alpha: 0.95 * (1 - t * t));
          canvas.drawCircle(o, p.size * unit, _fill);
        case _Kind.paper:
          // Flattern: die sichtbare Breite pendelt, als drehte sich das Blatt.
          final flip = math.cos(p.phase + p.age * 13);
          final w = p.size * unit * 1.15;
          final h = p.size * unit * 0.7 * (0.25 + 0.75 * flip.abs());
          final fade = t < 0.72 ? 1.0 : 1 - (t - 0.72) / 0.28;
          _fill.color =
              (flip < 0
                      ? Color.lerp(p.color, const Color(0xFF000000), 0.14)!
                      : p.color)
                  .withValues(alpha: fade);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(p.phase + p.age * p.spin);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w, height: h),
              Radius.circular(w * 0.12),
            ),
            _fill,
          );
          canvas.restore();
        case _Kind.shard:
          final r = p.size * unit * (1 - 0.3 * t);
          final a0 = p.phase + p.age * p.spin;
          _path.reset();
          for (var k = 0; k < 3; k++) {
            // ungleichseitig, damit es nach Bruchstück aussieht
            final a = a0 + k * 2.0944 + (k == 1 ? 0.5 : 0);
            final rr = r * (k == 2 ? 0.7 : 1.0);
            final q = Offset(
              o.dx + math.cos(a) * rr,
              o.dy + math.sin(a) * rr * 0.85,
            );
            k == 0 ? _path.moveTo(q.dx, q.dy) : _path.lineTo(q.dx, q.dy);
          }
          _path.close();
          _fill.color = p.color.withValues(
            alpha: t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3,
          );
          canvas.drawPath(_path, _fill);
        case _Kind.spark:
          // Vierzackiger Stern, der kurz aufgeht und wieder verschwindet.
          final s = math.sin(math.pi * t);
          final r = p.size * unit * s;
          _path
            ..reset()
            ..moveTo(o.dx, o.dy - r)
            ..quadraticBezierTo(o.dx, o.dy, o.dx + r * 0.8, o.dy)
            ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
            ..quadraticBezierTo(o.dx, o.dy, o.dx - r * 0.8, o.dy)
            ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
            ..close();
          _fill.color = p.color.withValues(alpha: 0.95 * s);
          canvas.drawPath(_path, _fill);
      }
    }
  }
}
