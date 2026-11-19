import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../services/feedback/game_feedback.dart';
import '../services/storage/stats_store.dart';
import 'core/board.dart';
import 'core/game_session.dart';
import 'core/piece.dart';
import 'core/player_stats.dart';
import '../shared/theme/fs_colors.dart';
import 'core/rules.dart';
import 'projection/iso_projection.dart';
import 'render/background.dart';
import 'render/sprite_set.dart';
import 'render/tower_renderer.dart';

/// Ergebnis einer beendeten Runde für den Ergebnisbildschirm.
@immutable
class RoundResult {
  const RoundResult({
    required this.reason,
    required this.score,
    required this.height,
    required this.pieces,
    required this.bestCombo,
    required this.newBest,
    required this.stats,
    required this.seconds,
    this.maxSpread = 4,
    this.blockCause,
    this.blockedPiece,
  });

  /// Bei "kein Platz mehr": der Baustein, der nirgends passte, und warum.
  final BlockCause? blockCause;
  final PieceShape? blockedPiece;
  final GameOverReason reason;
  final int score, height, pieces, bestCombo;
  final bool newBest;
  final PlayerStats stats;

  /// Zuletzt erlaubter Höhenunterschied (für die Begründung des Spielendes).
  final int maxSpread;

  /// Reine Spielzeit der Runde in Sekunden (ohne Pausen).
  final int seconds;
}

/// Was die Flutter-Oberfläche anzeigen muss.
@immutable
class HudState {
  const HudState({
    this.score = 0,
    this.height = 0,
    this.best = 0,
    this.combo = 0,
    this.multiplier = 1,
    this.canDrop = true,
    this.hint,
    this.warning,
    this.notice,
    this.result,
  });
  final int score, height, best, combo;
  final double multiplier;
  final bool canDrop;

  /// Warum die aktuelle Position ungültig ist.
  final String? hint;

  /// Vorwarnung, wenn nur noch wenige Ablagen möglich sind.
  final String? warning;

  /// Kurze Ansage beim Erreichen einer Etappe (was sich ab jetzt ändert).
  final String? notice;
  final RoundResult? result;
}

class _Popup {
  _Popup(
    this.text,
    this.wx,
    this.wy,
    this.z,
    this.delay, {
    this.accent = false,
  });
  final String text;
  final double wx, wy, z, delay;
  final bool accent;
  double t = 0;
}

class _Dust {
  _Dust(this.wx, this.wy, this.z, this.vx, this.vy, this.size);
  double wx, wy;
  final double z, vx, vy, size;
  double t = 0;
}

/// Was der Spieler gerade getan hat (für das Tutorial).
enum GameEvent { moved, rotated, placed }

/// Verbindet Spiellogik, Animationen und Darstellung.
class FlipstackGame extends FlameGame {
  FlipstackGame({
    StatsStore? store,
    this.showFps = false,
    this.seed,
    this.autoplay = false,
    GameFeedback? feedback,
    this.onEvent,
  }) : store = store ?? MemoryStatsStore(),
       feedback = feedback ?? SilentFeedback();

  final StatsStore store;
  final GameFeedback feedback;
  final void Function(GameEvent event)? onEvent;

  /// Im Hauptmenü zeigt das Spiel einen Beispielturm, der sich gelegentlich
  /// dreht; Eingaben sind dann gesperrt.
  bool _menu = true;
  double _menuT = 0;
  double _playSeconds = 0;

  bool get inMenu => _menu;
  PlayerStats get stats => _stats;
  final bool showFps;
  final int? seed;

  /// Testhilfe: spielt selbstständig gültige Züge.
  final bool autoplay;
  double _autoT = 0;
  (int, int, int)? _autoTarget;
  final _autoRng = math.Random(1);

  static const rotationSeconds = 0.30;
  static const squashSeconds = 0.32;
  static const gameOverSeconds = 1.2;
  static const warnBelow = 4;

  final ValueNotifier<HudState> hud = ValueNotifier(const HudState());

  /// Wird wahr, sobald alle Assets geladen sind.
  final ValueNotifier<bool> assetsReady = ValueNotifier(false);

  /// Oberer sicherer Bereich (Notch), von der Oberfläche gesetzt.
  double safeTop = 0;

  late final TowerRenderer _renderer;
  final BackgroundPainter _background = BackgroundPainter();
  int _round = 0;
  final IsoProjection _projection = IsoProjection(origin: Offset.zero, unit: 1);
  late GameSession _session;
  PlayerStats _stats = const PlayerStats();
  RoundResult? _result;
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
  Set<int> _nudgeIds = const {};
  PlacementScore? _pendingScore;
  List<(int, int, int)> _landedCells = const [];

  double _cam = 0;
  double _time = 0;

  /// Etappen-Ansage und der Zeitpunkt, bis zu dem sie sichtbar bleibt.
  String? _notice;
  double _noticeUntil = 0;

  /// Nur zum Testen: Runde beginnt mit so vielen vollen Ebenen
  /// (`--dart-define=FS_START_HEIGHT=9`).
  static const _startHeight = int.fromEnvironment('FS_START_HEIGHT');
  double _overT = 0;
  final List<_Popup> _popups = [];
  final List<_Dust> _dust = [];
  final _rng = math.Random();
  final _popupPaint = TextPaint(
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF202B38),
    ),
  );
  final _popupAccent = TextPaint(
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: Color(0xFFD9573F),
    ),
  );
  final _dustPaint = Paint();

  double get _thetaDeg {
    final target = _session.orientation * 90.0;
    return _fromDeg +
        (target - _fromDeg) *
            Curves.easeInOutCubic.transform(_rotT.clamp(0, 1));
  }

  @override
  Color backgroundColor() => _background.theme.bottom;

  @override
  Future<void> onLoad() async {
    _renderer = TowerRenderer(await SpriteSet.load(FsColors.blocks));
    _stats = await store.load();
    if (showFps) {
      add(
        FpsTextComponent(position: Vector2(12, 130), scale: Vector2.all(0.5)),
      );
    }
    if (autoplay) {
      restart();
    } else {
      showMenu();
    }
    _ready = true;
    assetsReady.value = true;
  }

  /// Zeigt den Beispielturm für das Hauptmenü.
  void showMenu() {
    _menu = true;
    _menuT = 0;
    _resetRound(GameSession(seed: 11));
    final s = _session;
    final rng = math.Random(11);
    for (var i = 0; i < 12 && s.phase == GamePhase.preview; i++) {
      final o = s.rules.validPlacements(s.board, s.current);
      int cost((int, int, int) c) {
        final p = s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3);
        return p.z0 * 10 + (p.columns - p.supported) * 25 + rng.nextInt(4);
      }

      o.sort((a, b) => cost(a).compareTo(cost(b)));
      s.orientation = o.first.$3;
      s.moveTo(o.first.$1, o.first.$2);
      s.place();
      s.finishPlacing();
    }
    s.orientation = 0;
    _publish();
  }

  // ---------------------------------------------------------------- Eingaben

  /// Startet eine neue Runde.
  void restart() {
    _menu = false;
    _playSeconds = 0;
    final session = GameSession(seed: seed);
    for (var z = 0; z < _startHeight; z++) {
      for (var i = 0; i < session.grid * session.grid; i++) {
        session.board.add(
          Cell(i % session.grid, i ~/ session.grid, z, (i + z) % 8),
        );
      }
    }
    _resetRound(session);
    feedback.spawn();
    _publish();
  }

  void _resetRound(GameSession session) {
    _session = session;
    // Jede Runde eine andere Farbstimmung (später frei wählbar)
    _background.theme =
        BackgroundTheme.all[_round++ % BackgroundTheme.all.length];
    _result = null;
    _notice = null;
    _fromDeg = 0;
    _rotT = 1;
    _queuedRotation = null;
    _fallId = _squashId = -1;
    _nudgeIds = const {};
    _autoTarget = null;
    _overT = 0;
    _popups.clear();
    _dust.clear();
    _snapHover();
    _spawnT = 0;
  }

  /// +1 = Vierteldrehung gegen den Uhrzeigersinn (von oben gesehen, Knopf
  /// "links"), -1 = im Uhrzeigersinn (Knopf "rechts").
  void rotate(int dir) {
    if (!_ready || _menu) return;
    if (_session.phase == GamePhase.rotating ||
        _session.phase == GamePhase.placing) {
      _queuedRotation = dir;
      return;
    }
    final from = _session.orientation * 90.0;
    if (_session.rotate(dir)) {
      _fromDeg = from;
      _rotT = 0;
      feedback.rotate();
      onEvent?.call(GameEvent.rotated);
      _publish();
    }
  }

  void dragStart() {
    _dragX = _session.wx.toDouble();
    _dragY = _session.wy.toDouble();
  }

  void dragUpdate(Offset delta) {
    if (!_ready || _menu) return;
    final (dx, dy) = _projection.groundDelta(delta);
    final maxX = (_session.grid - _session.current.width).toDouble();
    final maxY = (_session.grid - _session.current.depth).toDouble();
    _dragX = (_dragX + dx).clamp(-0.45, maxX + 0.45);
    _dragY = (_dragY + dy).clamp(-0.45, maxY + 0.45);
    if (_session.moveTo(_dragX.round(), _dragY.round())) {
      feedback.move();
      onEvent?.call(GameEvent.moved);
      _publish();
    }
  }

  void drop() {
    if (!_ready || _menu || _session.phase != GamePhase.preview) return;
    final hover = _hz;
    final r = _session.place();
    if (r == null) {
      _shakeT = 0;
      feedback.invalid();
      return;
    }
    final (p, s, id) = r;
    _fallId = id;
    _fallFrom = hover - p.z0;
    _fallT = 0;
    _fallDur = (0.11 * math.sqrt(_fallFrom)).clamp(0.14, 0.42);
    _pendingScore = s;
    _landedCells = p.cells;
    feedback.drop();
    _publish();
  }

  // --------------------------------------------------------------- Ablauf

  @override
  void update(double dt) {
    super.update(dt);
    if (!_ready) return;
    final s = _session;
    _time += dt;
    if (_notice != null && _time >= _noticeUntil) {
      _notice = null;
      _publish();
    }
    if (_menu) {
      // Beispielturm dreht sich alle paar Sekunden um 90° (zeigt die Kernmechanik)
      _menuT += dt;
      if (_menuT > 2.8 && s.phase == GamePhase.preview) {
        _menuT = 0;
        _fromDeg = s.orientation * 90.0;
        if (s.rotate(1)) _rotT = 0;
      }
    } else if (s.phase != GamePhase.gameOver) {
      _playSeconds += dt;
    }

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
      if (_fallT >= 1) _land();
    }
    if (_squashT < 1) _squashT = math.min(1, _squashT + dt / squashSeconds);
    if (_spawnT < 1) _spawnT = math.min(1, _spawnT + dt / 0.2);
    if (_shakeT < 1) _shakeT = math.min(1, _shakeT + dt / 0.3);

    if (s.phase == GamePhase.gameOver && _overT < 1) {
      _overT = math.min(1, _overT + dt / gameOverSeconds);
      if (_overT >= 1) _publish();
    }

    final k = 1 - math.exp(-dt * 26);
    _hx += (s.wx - _hx) * k;
    _hy += (s.wy - _hy) * k;
    _hz += (s.height + 2.4 - _hz) * (1 - math.exp(-dt * 8));
    _cam += (math.max(0, s.height - 3) - _cam) * (1 - math.exp(-dt * 4));

    if (autoplay && !_menu) _autoplayStep(dt);

    for (final p in _popups) {
      p.t += dt / 1.0;
    }
    _popups.removeWhere((p) => p.t >= 1 + p.delay);
    for (final d in _dust) {
      d.t += dt / 0.45;
      d.wx += d.vx * dt * (1 - d.t).clamp(0, 1);
      d.wy += d.vy * dt * (1 - d.t).clamp(0, 1);
    }
    _dust.removeWhere((d) => d.t >= 1);
  }

  /// Der fallende Baustein ist angekommen.
  void _land() {
    final s = _session;
    final id = _fallId;
    _squashId = id;
    _squashT = 0;
    _fallId = -1;
    final sc = _pendingScore!;
    feedback.land();
    if (sc.stage > 0) {
      feedback.milestone();
      _notice = _stageNotice(sc);
      _noticeUntil = _time + 4.5;
    } else if (sc.milestones > 0) {
      feedback.milestone();
    } else if (sc.layers > 0) {
      feedback.layer();
    } else {
      feedback.combo(sc.combo);
    }

    // Bausteine direkt darunter federn leicht mit (rein optisch, kehren exakt zurück)
    final below = {for (final (x, y, z) in _landedCells) (x, y, z - 1)};
    _nudgeIds = {
      for (final c in s.board.cells)
        if (c.pieceId != id && below.contains((c.x, c.y, c.z))) c.pieceId,
    };

    _spawnEffects(sc);
    s.finishPlacing();
    if (s.phase == GamePhase.gameOver) {
      final newBest = s.score > _stats.bestScore && s.score > 0;
      _stats = _stats.recordRound(s);
      store.save(_stats);
      _result = RoundResult(
        reason: s.gameOverReason!,
        score: s.score,
        height: s.height,
        pieces: s.piecesPlaced,
        bestCombo: s.bestCombo,
        newBest: newBest,
        stats: _stats,
        seconds: _playSeconds.round(),
        maxSpread: s.maxSpread,
        blockCause: s.blockCause,
        blockedPiece: s.blockCause == null ? null : s.current,
      );
      _overT = 0;
      newBest ? feedback.highscore() : feedback.gameOver();
    } else {
      _snapHover();
      _spawnT = 0;
      feedback.spawn();
    }
    onEvent?.call(GameEvent.placed);
    _publish();
    _runQueuedRotation();
  }

  /// Was sich mit der erreichten Etappe ändert.
  String _stageNotice(PlacementScore sc) {
    final big = PieceLibrary.bigPiecesFromHeight;
    final change = sc.newSpread != null
        ? 'Ab jetzt höchstens ${sc.newSpread} Ebenen Unterschied'
        : sc.stage == big[0]
        ? 'Bald kommen Formen aus fünf Würfeln'
        : sc.stage == big[1]
        ? 'Bald kommen noch sperrigere Formen'
        : 'Weiter so';
    return 'Etappe ${sc.stage} · $change';
  }

  void _spawnEffects(PlacementScore sc) {
    final half = (_session.grid - 1) / 2;
    var cx = 0.0, cy = 0.0, top = 0, bottom = 1 << 20;
    for (final (x, y, z) in _landedCells) {
      cx += x;
      cy += y;
      top = math.max(top, z);
      bottom = math.min(bottom, z);
    }
    cx = cx / _landedCells.length - half;
    cy = cy / _landedCells.length - half;

    final mult = sc.multiplier > 1 ? '  ×${_fmt(sc.multiplier)}' : '';
    var delay = 0.0;
    void pop(String text, {bool accent = false}) {
      _popups.add(_Popup(text, cx, cy, top + 1.7, delay, accent: accent));
      delay += 0.16;
    }

    pop('+${sc.placement}$mult');
    if (sc.layers > 0) pop('Ebene voll  +${sc.layerBonus}', accent: true);
    if (sc.milestones > 0) {
      pop('Höhe ${_session.height}  +${sc.milestoneBonus}', accent: true);
    }
    if (sc.stage > 0) {
      pop('Etappe ${sc.stage}  +${sc.stageBonus}', accent: true);
    }

    // Staub am Fuss des Bausteins
    for (final (x, y, z) in _landedCells) {
      if (z != bottom) continue;
      for (var i = 0; i < 3; i++) {
        final a = _rng.nextDouble() * math.pi * 2;
        final v = 1.2 + _rng.nextDouble() * 1.4;
        _dust.add(
          _Dust(
            x - half + math.cos(a) * 0.45,
            y - half + math.sin(a) * 0.45,
            z + 0.06,
            math.cos(a) * v,
            math.sin(a) * v,
            0.05 + _rng.nextDouble() * 0.06,
          ),
        );
      }
    }
  }

  static String _fmt(double m) => m.toStringAsFixed(1).replaceAll('.', ',');

  void _autoplayStep(double dt) {
    final s = _session;
    if (s.phase != GamePhase.preview) return;
    _autoT += dt;
    if (_autoT < 0.4) return;
    _autoT = 0;
    if (_autoTarget == null) {
      final o = s.rules.validPlacements(s.board, s.current);
      int cost((int, int, int) c) {
        final p = s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3);
        return p.z0 * 10 + (p.columns - p.supported) * 25;
      }

      o.sort((a, b) => cost(a).compareTo(cost(b)));
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
    final preview = s.phase == GamePhase.preview;
    final p = s.placement;
    hud.value = HudState(
      score: s.score,
      height: s.height,
      best: math.max(_stats.bestScore, s.score),
      combo: s.combo,
      multiplier: GameSession.multiplierFor(s.combo + 1),
      canDrop: preview && p.isValid,
      hint: !preview || p.isValid
          ? null
          : switch (p.error) {
              PlacementError.unsupported => 'Liegt zu wenig auf',
              PlacementError.tooUneven =>
                'Zu hoch – erst die markierten Felder füllen',
              _ => null,
            },
      warning: preview && s.placementsLeft < warnBelow
          ? (s.placementsLeft == 1
                ? 'Nur noch 1 Platz'
                : 'Nur noch ${s.placementsLeft} Plätze')
          : null,
      notice: _time < _noticeUntil ? _notice : null,
      result: _overT >= 1 ? _result : null,
    );
  }

  /// Für die Oberfläche: zeichnet einen Baustein (z. B. im Ergebnis).
  void paintPiece(Canvas canvas, PieceShape shape, Offset center, double unit) {
    if (_ready) _renderer.renderPiece(canvas, shape, center, unit);
  }

  // ------------------------------------------------------------ Darstellung

  @override
  void render(Canvas canvas) {
    if (!_ready) return;
    final s = _session;
    final n = s.grid;
    final half = (n - 1) / 2;

    // Kamera: im Spiel folgt sie der Bauhöhe; am Ende zeigt sie den ganzen Turm.
    final playUnit = size.x / 8.2;
    final over = Curves.easeInOutCubic.transform(_overT);
    _projection.unit = playUnit;
    final playY =
        size.y * (_menu ? 0.57 : 0.60) + _cam * _projection.unitHeight;
    if (over > 0) {
      final needed =
          s.height * 0.8165 + 5.2; // Turmhöhe + Plattformtiefe (Welteinheiten)
      final fitUnit = math.min(playUnit, size.y * 0.40 / needed);
      _projection.unit = playUnit + (fitUnit - playUnit) * over;
      final fitY =
          safeTop + size.y * 0.03 + (s.height * 0.8165 + 2.2) * fitUnit;
      _projection.origin = Offset(size.x / 2, playY + (fitY - playY) * over);
    } else {
      _projection.origin = Offset(size.x / 2, playY);
    }

    final thetaDeg = _thetaDeg;
    _background.render(
      canvas,
      size.toSize(),
      _time,
      _projection.projectWorld(0, 0, s.height * 0.5),
    );
    _renderer.renderGroundShadow(
      canvas,
      _projection,
      thetaDeg,
      const Color(0x38202B38),
    );
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
    final wobble = _squashT < 1
        ? math.exp(-5.5 * _squashT) * math.cos(_squashT * 15)
        : 0.0;
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
          squash: c.pieceId == _squashId
              ? 1 - 0.13 * wobble
              : _nudgeIds.contains(c.pieceId)
              ? 1 - 0.035 * wobble
              : 1,
          cell: falling ? null : (c.x, c.y, c.z),
        ),
      );
    }

    final blocked =
        s.phase == GamePhase.gameOver && s.blockCause != null && _overT < 1;
    if (_menu) {
      // im Menü kein schwebender Baustein
    } else if (s.phase == GamePhase.preview ||
        s.phase == GamePhase.rotating ||
        blocked) {
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
            opacity: blocked ? (1 - _overT * _overT) : _spawnT.clamp(0, 1),
            invalid: blocked,
          ),
        );
      }
    }

    // Höhenregel sichtbar machen: Sobald der Turm ungleichmäßig wird, zeigt ein
    // Rahmen die höchste erlaubte Bauhöhe, und die tiefsten Felder pulsieren.
    final spread = s.height - s.board.minHeight;
    final maxSpread = s.maxSpread;
    final blockedByHeight =
        s.phase == GamePhase.preview &&
        s.placement.error == PlacementError.tooUneven;
    final showGuide =
        !_menu &&
        s.phase != GamePhase.gameOver &&
        (spread >= maxSpread - 1 || blockedByHeight);
    final pulse = 0.5 + 0.5 * math.sin(_time * 5);
    final lowest = <int>{};
    if (showGuide) {
      final lo = s.board.minHeight;
      for (var i = 0; i < n * n; i++) {
        if (s.board.heightAt(i % n, i ~/ n) == lo) lowest.add(i);
      }
    }

    _renderer.render(
      canvas,
      _projection,
      cubes,
      thetaDeg,
      heights,
      markerCorner: (-1, -1),
      highlight: lowest,
      highlightColor: Color.fromRGBO(53, 182, 164, 0.30 + 0.35 * pulse),
    );

    if (showGuide) {
      _renderer.renderLimitFrame(
        canvas,
        _projection,
        s.heightLimit.toDouble(),
        thetaDeg,
        blockedByHeight
            ? Color.fromRGBO(229, 72, 77, 0.65 + 0.35 * pulse)
            : const Color(0xB3F1BD58),
      );
    }

    for (final d in _dust) {
      final (wx, wy) = IsoProjection.rotate(d.wx, d.wy, theta);
      final o = _projection.projectWorld(wx, wy, d.z + d.t * 0.25);
      _dustPaint.color = Color.fromRGBO(255, 250, 240, 0.75 * (1 - d.t));
      canvas.drawCircle(o, d.size * _projection.unit * (0.6 + d.t), _dustPaint);
    }

    for (final p in _popups) {
      final t = p.t - p.delay;
      if (t < 0) continue;
      final (wx, wy) = IsoProjection.rotate(p.wx, p.wy, theta);
      final o = _projection.projectWorld(wx, wy, p.z + t * 0.9 + p.delay * 4.4);
      final a = (1 - t * t).clamp(0.0, 1.0);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      (p.accent ? _popupAccent : _popupPaint).render(
        canvas,
        p.text,
        Vector2(o.dx, o.dy),
        anchor: Anchor.center,
      );
      canvas.restore();
    }

    // Nächster Baustein (oben rechts)
    if (!_menu && s.phase != GamePhase.gameOver) {
      _renderer.renderPiece(
        canvas,
        s.next,
        Offset(size.x - 58, safeTop + 116),
        15,
      );
    }
    super.render(canvas);
  }
}
