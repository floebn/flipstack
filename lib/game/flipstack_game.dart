import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter/services.dart' show HapticFeedback;

import 'core/game_session.dart';
import 'core/rules.dart';
import 'projection/iso_projection.dart';
import 'render/sprite_set.dart';
import 'render/tower_renderer.dart';

/// Was die Flutter-Oberfläche anzeigen muss.
@immutable
class HudState {
  const HudState({
    this.score = 0,
    this.height = 0,
    this.best = 0,
    this.canDrop = true,
    this.gameOver,
    this.newBest = false,
    this.hint,
  });
  final int score, height, best;
  final bool canDrop;
  final GameOverReason? gameOver;
  final bool newBest;
  final String? hint;
}

class _Popup {
  _Popup(this.text, this.wx, this.wy, this.z);
  final String text;
  final double wx, wy, z;
  double t = 0;
}

/// Verbindet Spiellogik, Animationen und Darstellung (Phase 1b: Prototyp).
class FlipstackGame extends FlameGame {
  FlipstackGame({this.showFps = false, this.seed, this.autoplay = false});

  final bool showFps;
  final int? seed;

  /// Testhilfe: spielt zufällige gültige Züge.
  final bool autoplay;
  double _autoT = 0;
  (int, int, int)? _autoTarget;
  final _autoRng = math.Random(1);

  static const rotationSeconds = 0.30;
  static const squashSeconds = 0.32;

  final ValueNotifier<HudState> hud = ValueNotifier(const HudState());

  /// Oberer sicherer Bereich (Notch), von der Oberfläche gesetzt.
  double safeTop = 0;

  late final TowerRenderer _renderer;
  final IsoProjection _projection = IsoProjection(origin: Offset.zero, unit: 1);
  late GameSession _session;
  int _best = 0;
  bool _ready = false;

  // Rotation
  double _fromDeg = 0;
  double _rotT = 1;
  int? _queuedRotation;

  // Schwebender Baustein (weich nachgeführt)
  double _hx = 0, _hy = 0, _hz = 3;
  double _dragX = 0, _dragY = 0;
  double _spawnT = 1;
  double _shakeT = 1;

  // Fallender / gelandeter Baustein
  int _fallId = -1;
  double _fallFrom = 0, _fallT = 0, _fallDur = 0.2;
  int _squashId = -1;
  double _squashT = 1;

  double _cam = 0;
  final List<_Popup> _popups = [];
  final _popupPaint = TextPaint(
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF202B38),
    ),
  );

  double get _thetaDeg {
    final target = _session.orientation * 90.0;
    return _fromDeg +
        (target - _fromDeg) *
            Curves.easeInOutCubic.transform(_rotT.clamp(0, 1));
  }

  @override
  Color backgroundColor() => const Color(0xFFEFE6D6);

  @override
  Future<void> onLoad() async {
    _renderer = TowerRenderer(await SpriteSet.load());
    if (showFps) {
      add(
        FpsTextComponent(position: Vector2(12, 120), scale: Vector2.all(0.5)),
      );
    }
    restart();
    _ready = true;
  }

  // ---------------------------------------------------------------- Eingaben

  void restart() {
    _session = GameSession(seed: seed);
    _fromDeg = 0;
    _rotT = 1;
    _queuedRotation = null;
    _fallId = _squashId = -1;
    _popups.clear();
    _snapHover();
    _spawnT = 0;
    _publish();
  }

  /// +1 = Vierteldrehung gegen den Uhrzeigersinn (von oben gesehen, Knopf
  /// "links"), -1 = im Uhrzeigersinn (Knopf "rechts").
  void rotate(int dir) {
    if (!_ready) return;
    if (_session.phase == GamePhase.rotating ||
        _session.phase == GamePhase.placing) {
      _queuedRotation = dir;
      return;
    }
    final from = _session.orientation * 90.0;
    if (_session.rotate(dir)) {
      _fromDeg = from;
      _rotT = 0;
      HapticFeedback.selectionClick();
      _publish();
    }
  }

  void dragStart() {
    _dragX = _session.wx.toDouble();
    _dragY = _session.wy.toDouble();
  }

  void dragUpdate(Offset delta) {
    if (!_ready) return;
    final (dx, dy) = _projection.groundDelta(delta);
    final maxX = (_session.grid - _session.current.width).toDouble();
    final maxY = (_session.grid - _session.current.depth).toDouble();
    _dragX = (_dragX + dx).clamp(-0.45, maxX + 0.45);
    _dragY = (_dragY + dy).clamp(-0.45, maxY + 0.45);
    if (_session.moveTo(_dragX.round(), _dragY.round())) {
      HapticFeedback.selectionClick();
      _publish();
    }
  }

  void drop() {
    if (!_ready || _session.phase != GamePhase.preview) return;
    final hover = _hz;
    final r = _session.place();
    if (r == null) {
      _shakeT = 0;
      HapticFeedback.heavyImpact();
      return;
    }
    final (p, s, id) = r;
    _fallId = id;
    _fallFrom = hover - p.z0;
    _fallT = 0;
    _fallDur = (0.11 * math.sqrt(_fallFrom)).clamp(0.14, 0.42);
    // Punkte über dem Baustein einblenden
    var cx = 0.0, cy = 0.0, top = 0;
    for (final (x, y, z) in p.cells) {
      cx += x;
      cy += y;
      top = math.max(top, z);
    }
    final h = (_session.grid - 1) / 2;
    final label = s.layers > 0
        ? '+${s.base}  Ebene +${s.layerBonus}'
        : '+${s.base}';
    _popups.add(
      _Popup(
        label,
        cx / p.cells.length - h,
        cy / p.cells.length - h,
        top + 1.6,
      ),
    );
    _publish();
  }

  // --------------------------------------------------------------- Ablauf

  @override
  void update(double dt) {
    super.update(dt);
    if (!_ready) return;
    final s = _session;

    if (s.phase == GamePhase.rotating) {
      _rotT += dt / rotationSeconds;
      if (_rotT >= 1) {
        _rotT = 1;
        s.finishRotating();
        _publish();
        _runQueuedRotation();
      }
    }

    if (_fallId >= 0) {
      _fallT += dt / _fallDur;
      if (_fallT >= 1) {
        _squashId = _fallId;
        _squashT = 0;
        _fallId = -1;
        HapticFeedback.mediumImpact();
        s.finishPlacing();
        if (s.phase == GamePhase.gameOver) {
          if (s.score > _best) _best = s.score;
        } else {
          _snapHover();
          _spawnT = 0;
        }
        _publish();
        _runQueuedRotation();
      }
    }
    if (_squashT < 1) _squashT = math.min(1, _squashT + dt / squashSeconds);
    if (_spawnT < 1) _spawnT = math.min(1, _spawnT + dt / 0.2);
    if (_shakeT < 1) _shakeT = math.min(1, _shakeT + dt / 0.3);

    final k = 1 - math.exp(-dt * 26);
    _hx += (s.wx - _hx) * k;
    _hy += (s.wy - _hy) * k;
    _hz += (s.height + 2.4 - _hz) * (1 - math.exp(-dt * 8));
    _cam += (math.max(0, s.height - 3) - _cam) * (1 - math.exp(-dt * 4));

    if (autoplay) _autoplayStep(dt);

    for (final p in _popups) {
      p.t += dt / 0.9;
    }
    _popups.removeWhere((p) => p.t >= 1);
  }

  void _autoplayStep(double dt) {
    final s = _session;
    if (s.phase != GamePhase.preview) return;
    _autoT += dt;
    if (_autoT < 0.4) return;
    _autoT = 0;
    if (_autoTarget == null) {
      final o = s.rules.validPlacements(s.board, s.current);
      // bevorzugt tiefe, voll gestützte Positionen
      o.sort((a, b) {
        int cost((int, int, int) c) {
          final p = s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3);
          return p.z0 * 10 + (p.columns - p.supported) * 25;
        }

        return cost(a).compareTo(cost(b));
      });
      _autoTarget = o[_autoRng.nextInt(math.min(3, o.length))];
    }
    final (x, y, r) = _autoTarget!;
    if ((s.orientation - r) % 4 != 0) {
      rotate(1);
    } else if (s.wx != x || s.wy != y) {
      s.moveTo(x, y);
      _publish();
    } else {
      _autoTarget = null;
      drop();
    }
  }

  void _runQueuedRotation() {
    final q = _queuedRotation;
    _queuedRotation = null;
    if (q != null) rotate(q);
  }

  void _snapHover() {
    _hx = _session.wx.toDouble();
    _hy = _session.wy.toDouble();
  }

  void _publish() {
    final s = _session;
    final p = s.placement;
    final over = s.phase == GamePhase.gameOver;
    hud.value = HudState(
      score: s.score,
      height: s.height,
      best: _best,
      canDrop: s.phase == GamePhase.preview && p.isValid,
      gameOver: over ? s.gameOverReason : null,
      newBest: over && s.score > 0 && s.score >= _best,
      hint: s.phase != GamePhase.preview || p.isValid
          ? null
          : switch (p.error) {
              PlacementError.unsupported => 'Liegt zu wenig auf',
              PlacementError.tooUneven => 'Turm wird zu ungleichmäßig',
              _ => null,
            },
    );
  }

  // ------------------------------------------------------------ Darstellung

  @override
  void render(Canvas canvas) {
    if (!_ready) return;
    final s = _session;
    final n = s.grid;
    final half = (n - 1) / 2;
    _projection
      ..unit = size.x / 8.2
      ..origin = Offset(
        size.x / 2,
        size.y * 0.60 + _cam * _projection.unitHeight,
      );

    final thetaDeg = _thetaDeg;
    final theta = thetaDeg * math.pi / 180;
    final frame = _renderer.sprites.frameFor(thetaDeg);
    final cubes = <RenderCube>[];

    // Säulenhöhen für Schatten: fallender Baustein wirft noch keinen
    final heights = List.filled(n * n, 0);
    for (final c in s.board.cells) {
      if (c.pieceId == _fallId) continue;
      final i = c.y * n + c.x;
      if (c.z + 1 > heights[i]) heights[i] = c.z + 1;
    }

    final fall = _fallId >= 0 ? _fallFrom * (1 - _fallT * _fallT) : 0.0;
    final squash = _squashT < 1
        ? 1 - 0.13 * math.exp(-5.5 * _squashT) * math.cos(_squashT * 15)
        : 1.0;
    for (final c in s.board.cells) {
      final (wx, wy) = IsoProjection.rotate(c.x - half, c.y - half, theta);
      final falling = c.pieceId == _fallId;
      cubes.add(
        RenderCube(
          wx: wx,
          wy: wy,
          z: c.z + 0.5 + (falling ? fall : 0),
          color: c.color,
          frame: frame,
          squash: c.pieceId == _squashId ? squash : 1,
          shadowTop: !falling && heights[c.y * n + c.x] == c.z + 1
              ? (c.x, c.y, c.z + 1)
              : null,
        ),
      );
    }

    if (s.phase == GamePhase.preview || s.phase == GamePhase.rotating) {
      // Vorschau der Landeposition (nicht während der Drehung)
      if (s.phase == GamePhase.preview) {
        final p = s.placement;
        for (final (x, y, z) in p.cells) {
          if (s.board.isOccupied(x, y, z)) continue;
          final (wx, wy) = IsoProjection.rotate(x - half, y - half, theta);
          cubes.add(
            RenderCube(
              wx: wx,
              wy: wy,
              z: z + 0.5,
              color: s.current.color,
              frame: frame,
              opacity: 0.42,
              invalid: !p.isValid,
              solid: false,
            ),
          );
        }
      }
      // Schwebender Baustein: kamerafest, dreht sich nie mit
      final shake = _shakeT < 1
          ? math.sin(_shakeT * 28) * 0.09 * (1 - _shakeT)
          : 0.0;
      final appear = Curves.easeOutBack.transform(_spawnT);
      for (final (dx, dy, dz) in s.current.cells) {
        cubes.add(
          RenderCube(
            wx: _hx + dx - half + shake,
            wy: _hy + dy - half - shake,
            z: _hz + dz + 0.5 + (1 - appear) * 0.8,
            color: s.current.color,
            frame: 0,
            opacity: _spawnT.clamp(0, 1),
          ),
        );
      }
    }

    _renderer.render(
      canvas,
      _projection,
      cubes,
      thetaDeg,
      heights,
      markerCell: (0, 0),
    );

    for (final p in _popups) {
      final (wx, wy) = IsoProjection.rotate(p.wx, p.wy, theta);
      final o = _projection.projectWorld(wx, wy, p.z + p.t * 0.9);
      final a = (1 - p.t * p.t).clamp(0.0, 1.0);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      _popupPaint.render(
        canvas,
        p.text,
        Vector2(o.dx, o.dy),
        anchor: Anchor.center,
      );
      canvas.restore();
    }

    // Nächster Baustein (oben rechts)
    if (s.phase != GamePhase.gameOver) {
      _renderer.renderPiece(
        canvas,
        s.next,
        Offset(size.x - 58, safeTop + 64),
        17,
      );
    }
    super.render(canvas);
  }
}
