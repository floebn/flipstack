import '../l10n/tr.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../services/feedback/game_feedback.dart';
import 'render/impact_fx.dart';
import '../services/storage/stats_store.dart';
import 'core/board.dart';
import 'core/game_session.dart';
import 'core/piece.dart';
import 'core/player_stats.dart';
import 'meta/rewards.dart';
import '../services/storage/profile_store.dart';
import 'render/looks.dart';
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
    this.rewards = const RoundRewards(),
    this.canRevive = false,
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

  /// Die Runde kann einmal fortgesetzt werden (zweite Chance).
  final bool canRevive;

  /// Münzen, erfüllte Aufgaben und neue Erfolge dieser Runde.
  final RoundRewards rewards;

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

/// Was der Spieler gerade getan hat (für das Tutorial).
enum GameEvent { moved, rotated, placed }

/// Verbindet Spiellogik, Animationen und Darstellung.
class FlipstackGame extends FlameGame {
  FlipstackGame({
    StatsStore? store,
    ProfileController? profile,
    this.showFps = false,
    this.seed,
    this.autoplay = false,
    GameFeedback? feedback,
    this.onEvent,
  }) : store = store ?? MemoryStatsStore(),
       profile = profile ?? ProfileController(MemoryProfileStore()),
       feedback = feedback ?? SilentFeedback();

  final StatsStore store;

  /// Belohnungsstand: Münzen, Aufgaben, Erfolge, gewähltes Aussehen.
  final ProfileController profile;
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

  /// Bis zu dieser Höhe sind Änderungen der Schwierigkeit schon angesagt.
  int _announcedHeight = 0;

  /// Rekordhöhe vor dieser Runde; eine Linie am Turm zeigt sie.
  int _recordHeight = 0;
  bool _recordAnnounced = false;
  double _noticeUntil = 0;

  /// Nur zum Testen: Runde beginnt mit so vielen vollen Ebenen
  /// (`--dart-define=FS_START_HEIGHT=9`).
  static const _startHeight = int.fromEnvironment('FS_START_HEIGHT');

  /// Nur zum Testen: spielt im Hauptmenü reihum alle Effekte ab
  /// (`--dart-define=FS_FX_DEMO=true`).
  static const _fxDemo = bool.fromEnvironment('FS_FX_DEMO');

  /// Nur für Aufnahmen im Selbstspiel: Pause zwischen den Schritten und ob
  /// immer die beste Ablage gewählt wird
  /// (`--dart-define=FS_AUTOPLAY_MS=150 --dart-define=FS_AUTOPLAY_BEST=true`).
  static const _autoMs = int.fromEnvironment(
    'FS_AUTOPLAY_MS',
    defaultValue: 400,
  );
  static const _autoBest = bool.fromEnvironment('FS_AUTOPLAY_BEST');
  double _fxDemoT = 0;
  int _fxDemoStep = 0;
  double _overT = 0;
  final List<_Popup> _popups = [];

  /// Staub, Konfetti oder Splitter, Druckwellen und Aufblitzen.
  final ImpactFx _fx = ImpactFx();

  /// Kurzer Ruck der Kamera beim Aufprall: Zeit seit dem Auslösen und Stärke
  /// in Welteinheiten.
  double _kickT = 1, _kickAmp = 0;

  /// Fallstreifen gibt es erst in einer Serie (Combo beim letzten Ablegen).
  bool _streaks = false;
  final Paint _streakPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _flashPaint = Paint();
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
  final _popupPaintLight = TextPaint(
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFFF2EEE5),
    ),
  );
  final _popupAccentLight = TextPaint(
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: Color(0xFFF7A893),
    ),
  );
  final _sceneImages = Images(prefix: 'assets/backgrounds/');

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
    await profile.load();
    _applyLook();
    profile.addListener(_applyLook);
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

  PlayerStats? _statsBeforeRound;
  Profile? _profileBeforeRound;

  /// Zweite Chance: setzt die beendete Runde einmal fort. Die Abrechnung
  /// (Statistik, Münzen, Aufgaben) wird zurückgenommen und am wirklichen Ende
  /// der Runde neu gemacht.
  bool revive() {
    final statsBefore = _statsBeforeRound, profileBefore = _profileBeforeRound;
    if (!_ready || statsBefore == null || profileBefore == null) return false;
    if (!_session.revive()) return false;
    _stats = statsBefore;
    store.save(_stats);
    profile.restore(profileBefore);
    _statsBeforeRound = null;
    _profileBeforeRound = null;
    _result = null;
    _overT = 0;
    _snapHover();
    _spawnT = 0;
    feedback.reward();
    _publish();
    return true;
  }

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

  /// Stand der laufenden Runde zum Speichern, oder `null`, wenn gerade keine
  /// Runde in Ruhe ist (Menü, fallender Stein, Spielende).
  Map<String, dynamic>? snapshot() {
    if (!_ready || _menu) return null;
    final s = _session;
    if (s.phase != GamePhase.preview && s.phase != GamePhase.rotating) {
      return null;
    }
    return {'session': s.toJson(), 'seconds': _playSeconds};
  }

  /// Setzt eine gespeicherte Runde fort. `false`, wenn sie nicht lesbar ist.
  bool resumeRound(Map<String, dynamic> saved) {
    if (!_ready) return false;
    final raw = saved['session'];
    final session = raw is Map
        ? GameSession.fromJson(raw.cast<String, dynamic>())
        : null;
    if (session == null) return false;
    _menu = false;
    final seconds = saved['seconds'];
    _playSeconds = seconds is num ? seconds.toDouble() : 0;
    _resetRound(session);
    // Kamera direkt auf die Bauhöhe, nicht vom Boden hochfahren
    _cam = math.max(0, session.height - 3).toDouble();
    feedback.spawn();
    _publish();
    return true;
  }

  /// Shop geöffnet: Der Beispielturm rückt nach oben und wird zur Bühne, auf
  /// der Freischaltungen anprobiert werden.
  bool shopStage = false;
  double _stageT = 0;
  Map<CosmeticCategory, String> _previewLook = const {};

  /// Zeigt Freischaltungen probeweise (auch nicht gekaufte). Leere Karte =
  /// wieder das gewählte Aussehen.
  void previewLook(Map<CosmeticCategory, String> ids) {
    _previewLook = Map.of(ids);
    if (_ready) _applyLook();
  }

  /// Zeigt den gewählten Effekt einmal auf der Bühne.
  void previewEffect() {
    if (!_ready) return;
    _fx.preview(_session.height.toDouble(), _renderer.sprites.palette);
    _kick(0.5);
  }

  /// Übernimmt das gewählte Aussehen (Blockfarben, Hintergrund, Plattform,
  /// Effekt) aus dem Belohnungsstand.
  void _applyLook() {
    final p = profile.profile;
    String look(CosmeticCategory c) => _previewLook[c] ?? p.equippedIn(c).id;
    final palette = Looks.palette(look(CosmeticCategory.blocks));
    if (!identical(palette, _renderer.sprites.palette)) {
      _renderer.sprites.setPalette(palette);
    }
    final (cubeFile, glossFile) = Looks.material(
      look(CosmeticCategory.material),
    );
    final materialId = look(CosmeticCategory.material);
    _renderer.sprites.setMaterial(
      cubeFile,
      glossFile,
      edgeInset: Looks.edgeInsets[materialId] ?? 0,
      seamDarken: Looks.seamDarken[materialId] ?? 0.2,
    );
    final bg = Looks.background(look(CosmeticCategory.background));
    if (!identical(bg, _background.theme)) {
      _background.theme = bg;
      _background.scene = null;
      fsDarkBackground.value = bg.dark;
      final file = bg.scene;
      if (file != null) {
        _sceneImages.load(file).then((img) {
          if (identical(_background.theme, bg)) _background.scene = img;
        });
      }
    }
    _renderer.sprites.setPlatform(
      Looks.platformSets[look(CosmeticCategory.platform)],
    );
    _renderer.platformFilter = Looks.platformFilter(
      look(CosmeticCategory.platform),
    );
    _fx.style = switch (look(CosmeticCategory.effect)) {
      'fx_confetti' => FxStyle.confetti,
      'fx_shards' => FxStyle.shards,
      _ => FxStyle.dust,
    };
  }

  void _resetRound(GameSession session) {
    _session = session;
    _result = null;
    _notice = null;
    _announcedHeight = session.height;
    _recordHeight = _stats.bestHeight;
    _recordAnnounced = false;
    _fromDeg = 0;
    _rotT = 1;
    _queuedRotation = null;
    _fallId = _squashId = -1;
    _nudgeIds = const {};
    _autoTarget = null;
    _overT = 0;
    _popups.clear();
    _fx.clear();
    _streaks = false;
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
    final stageTo = _menu && shopStage ? 1.0 : 0.0;
    if (_stageT != stageTo) {
      _stageT = (_stageT + (stageTo > _stageT ? dt : -dt) / 0.28).clamp(0, 1);
    }
    if (_menu && _fxDemo) {
      // Nur zum Ansehen der Effekte: wechselt zwischen Landung, voller Ebene
      // und Etappe.
      _fxDemoT += dt;
      if (_fxDemoT > 1.6) {
        _fxDemoT = 0;
        final palette = _renderer.sprites.palette;
        final z = math.max(0, s.height - 1);
        switch (_fxDemoStep++ % 3) {
          case 0:
            _fx.preview(s.height.toDouble(), palette);
            _kick(0.6);
          case 1:
            _fx.layer(z, s.grid / 2, palette, palette[0]);
            _kick(0.9);
          default:
            _fx.celebrate(s.height.toDouble(), 2, palette);
            _kick(1);
        }
      }
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
    _fx.update(dt);
    if (_kickT < 1) _kickT = math.min(1, _kickT + dt / 0.4);
  }

  /// Löst den Kamera-Ruck aus; [strength] 0..1.
  void _kick(double strength) {
    _kickT = 0;
    _kickAmp = 0.035 + 0.075 * strength.clamp(0, 1);
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

    // Änderungen der Schwierigkeit zwischen den Etappen (z. B. bei Höhe 15)
    if (sc.stage == 0) {
      for (var h = _announcedHeight + 1; h <= s.height; h++) {
        final change = s.curve.changeAt(h);
        if (change != null) {
          _notice = t('Höhe $h · $change', 'Height $h · $change');
          _noticeUntil = _time + 4.5;
        }
      }
    }
    _announcedHeight = s.height;
    if (!_recordAnnounced && _recordHeight >= 8 && s.height > _recordHeight) {
      _recordAnnounced = true;
      if (_time >= _noticeUntil) {
        _notice = t('Neue Rekordhöhe', 'New record height');
        _noticeUntil = _time + 3;
      }
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
      // Stand vor der Abrechnung merken: Bei einer zweiten Chance geht die
      // Runde weiter und wird erst an ihrem wirklichen Ende abgerechnet.
      _statsBeforeRound = _stats;
      _profileBeforeRound = profile.profile;
      _stats = _stats.recordRound(s);
      final rewards = profile.recordRound(
        RoundSummary(
          score: s.score,
          height: s.height,
          pieces: s.piecesPlaced,
          bestCombo: s.bestCombo,
          rotations: s.rotations,
          cleanPlacements: s.cleanPlacements,
          layers: s.fullLayers,
          revived: s.revived,
          flawlessHeight: s.flawlessHeight,
          rotationsAt20: s.rotationsAt20,
        ),
      );
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
        rewards: rewards,
        canRevive: s.canRevive,
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
    final change = sc.newSpread != null
        ? t(
            'Ab jetzt höchstens ${sc.newSpread} Ebenen Unterschied',
            'From now on at most ${sc.newSpread} levels of difference',
          )
        : _session.curve.changeAt(sc.stage) ?? t('Weiter so', 'Keep going');
    return t('Etappe ${sc.stage} · $change', 'Stage ${sc.stage} · $change');
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
    if (sc.layers > 0) {
      pop(
        t('Ebene voll  +${sc.layerBonus}', 'Layer full  +${sc.layerBonus}'),
        accent: true,
      );
    }
    if (sc.milestones > 0) {
      pop(
        t(
          'Höhe ${_session.height}  +${sc.milestoneBonus}',
          'Height ${_session.height}  +${sc.milestoneBonus}',
        ),
        accent: true,
      );
    }
    if (sc.stage > 0) {
      pop(
        t(
          'Etappe ${sc.stage}  +${sc.stageBonus}',
          'Stage ${sc.stage}  +${sc.stageBonus}',
        ),
        accent: true,
      );
    }

    // Wucht wächst mit Fallhöhe und Größe des Bausteins.
    final force =
        ((_fallFrom / 5).clamp(0.3, 1.0) * (0.75 + 0.07 * _landedCells.length))
            .clamp(0.0, 1.0);
    final palette = _renderer.sprites.palette;
    final color = palette[_session.board.cells.last.color % palette.length];
    _fx.landing(
      cells: [for (final (x, y, z) in _landedCells) (x - half, y - half, z)],
      color: color,
      palette: palette,
      force: force,
      clean: sc.cleanBonus > 0,
      combo: sc.combo,
    );
    // Der Ruck der Kamera wächst mit der Combo; ohne Serie bleibt er aus.
    if (sc.combo >= ImpactFx.warmCombo) {
      _kick(force * (sc.combo >= ImpactFx.hotCombo ? 0.7 : 0.3));
    }
    _streaks = sc.combo >= ImpactFx.warmCombo;

    // Volle Ebenen feiern: jede Höhe, die der Baustein berührt und die jetzt
    // lückenlos ist.
    if (sc.layers > 0) {
      final n = _session.grid;
      final filled = <int, int>{};
      for (final c in _session.board.cells) {
        filled[c.z] = (filled[c.z] ?? 0) + 1;
      }
      for (final z in {for (final (_, _, z) in _landedCells) z}) {
        if (filled[z] == n * n) _fx.layer(z, n / 2, palette, color);
      }
      _kick(0.9);
    }
    if (sc.stage > 0 || sc.milestones > 0) {
      _fx.celebrate(_session.height.toDouble(), sc.stage > 0 ? 2 : 1, palette);
      _kick(1);
    }
  }

  static String _fmt(double m) => formatDecimal(m);

  void _autoplayStep(double dt) {
    final s = _session;
    if (s.phase != GamePhase.preview) return;
    _autoT += dt;
    if (_autoT < _autoMs / 1000) return;
    _autoT = 0;
    if (_autoTarget == null) {
      final o = s.rules.validPlacements(s.board, s.current);
      int cost((int, int, int) c) {
        final p = s.rules.evaluate(s.board, s.current, c.$1, c.$2, c.$3);
        return p.z0 * 10 + (p.columns - p.supported) * 25;
      }

      o.sort((a, b) => cost(a).compareTo(cost(b)));
      // Für Aufnahmen: immer die beste Ablage statt einer der besten drei.
      _autoTarget = _autoBest
          ? o.first
          : o[_autoRng.nextInt(math.min(3, o.length))];
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
              PlacementError.unsupported => t(
                'Liegt zu wenig auf',
                'Too little support',
              ),
              PlacementError.tooUneven => t(
                'Zu hoch – erst die markierten Felder füllen',
                'Too high – fill the marked squares first',
              ),
              _ => null,
            },
      warning: preview && s.placementsLeft < warnBelow
          ? (s.placementsLeft == 1
                ? t('Nur noch 1 Platz', 'Only 1 spot left')
                : t(
                    'Nur noch ${s.placementsLeft} Plätze',
                    'Only ${s.placementsLeft} spots left',
                  ))
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
    final stage = Curves.easeInOutCubic.transform(_stageT);
    final playUnit = size.x / 8.2 * (1 - 0.34 * stage);
    final over = Curves.easeInOutCubic.transform(_overT);
    _projection.unit = playUnit;
    final playY =
        size.y * (_menu ? 0.57 - 0.325 * stage : 0.60) +
        _cam * _projection.unitHeight;
    if (over > 0) {
      final needed =
          s.height * 0.8165 + 5.2; // Turmhöhe + Plattformtiefe (Welteinheiten)
      final fitUnit = math.min(playUnit, size.y * 0.27 / needed);
      _projection.unit = playUnit + (fitUnit - playUnit) * over;
      final fitY =
          safeTop + size.y * 0.03 + (s.height * 0.8165 + 2.2) * fitUnit;
      _projection.origin = Offset(size.x / 2, playY + (fitY - playY) * over);
    } else {
      _projection.origin = Offset(size.x / 2, playY);
    }

    // Aufprall: das Bild sackt kurz nach unten und federt zurück.
    if (_kickT < 1) {
      final bump =
          _kickAmp *
          _projection.unit *
          math.exp(-9 * _kickT) *
          math.sin(_kickT * 24);
      _projection.origin = _projection.origin.translate(0, bump);
    }

    final thetaDeg = _thetaDeg;
    _background.render(
      canvas,
      size.toSize(),
      _time,
      _projection.projectWorld(0, 0, s.height * 0.5),
      // im Shop liegt die Szenerie über der Tafel (untere 60 %)
      sceneBottom: size.y * (1 - 0.60 * stage),
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
          squash: falling
              // im Fall leicht gestreckt, beim Aufprall gestaucht
              ? 1 + 0.05 * _fallT
              : c.pieceId == _squashId
              ? 1 - 0.15 * wobble
              : _nudgeIds.contains(c.pieceId)
              ? 1 - 0.05 * wobble
              : 1,
          cell: falling ? null : (c.x, c.y, c.z),
          slot: (falling ? 2 : 0, c.x, c.y, c.z),
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
            slot: (1, dx, dy, dz),
            cameraFixed: true,
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

    // Rekordhöhe: feiner Rahmen in Coral, sobald der Turm in ihre Nähe kommt
    if (!_menu &&
        s.phase != GamePhase.gameOver &&
        _recordHeight >= 8 &&
        s.height <= _recordHeight &&
        s.height >= _recordHeight - 4) {
      _renderer.renderLimitFrame(
        canvas,
        _projection,
        _recordHeight.toDouble(),
        thetaDeg,
        const Color(0x80F27C65),
      );
    }

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

    // Fallstreifen: kurze helle Striche über dem fallenden Baustein.
    if (_streaks && _fallId >= 0 && _fallT > 0.08) {
      final len = math.min(1.6, _fallFrom * 0.4) * _fallT;
      _streakPaint
        ..strokeWidth = _projection.unit * 0.05
        ..color = Color.fromRGBO(255, 255, 255, 0.5 * (1 - _fallT * 0.4));
      final tops = <(int, int), int>{};
      for (final (x, y, z) in _landedCells) {
        tops[(x, y)] = math.max(tops[(x, y)] ?? z, z);
      }
      tops.forEach((xy, z) {
        for (final off in const [-0.24, 0.24]) {
          final a = _projection.project(
            xy.$1 - half + off,
            xy.$2 - half - off,
            z + 1.05 + fall,
            theta,
          );
          canvas.drawLine(
            a,
            a.translate(0, -len * _projection.unitHeight),
            _streakPaint,
          );
        }
      });
    }

    _fx.render(canvas, _projection, theta);
    if (_fx.screenFlash > 0) {
      _flashPaint.color = Color.fromRGBO(255, 255, 255, _fx.screenFlash);
      canvas.drawRect(Offset.zero & size.toSize(), _flashPaint);
    }

    for (final p in _popups) {
      final t = p.t - p.delay;
      if (t < 0) continue;
      final (wx, wy) = IsoProjection.rotate(p.wx, p.wy, theta);
      final o = _projection.projectWorld(wx, wy, p.z + t * 0.9 + p.delay * 4.4);
      final a = (1 - t * t).clamp(0.0, 1.0);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      // Springt kurz auf; wichtige Meldungen etwas größer.
      final pop =
          (p.accent ? 1.18 : 1.0) *
          (0.55 + 0.45 * Curves.easeOutBack.transform((t / 0.2).clamp(0, 1)));
      final paint = _background.theme.dark
          ? (p.accent ? _popupAccentLight : _popupPaintLight)
          : (p.accent ? _popupAccent : _popupPaint);
      // Am Bildrand bleibt die Schrift vollständig sichtbar.
      final half = paint.getLineMetrics(p.text).width * pop / 2 + 12;
      final x = half * 2 >= size.x
          ? size.x / 2
          : o.dx.clamp(half, size.x - half).toDouble();
      canvas.translate(x, o.dy);
      canvas.scale(pop);
      paint.render(canvas, p.text, Vector2.zero(), anchor: Anchor.center);
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
