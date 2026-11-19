import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../features/gameplay/gameplay_overlays.dart';
import '../features/home/home_overlay.dart';
import '../features/settings/settings_sheet.dart';
import '../game/flipstack_game.dart';
import '../services/feedback/game_feedback.dart';
import '../services/storage/settings_store.dart';
import '../services/storage/stats_store.dart';
import 'app_flow.dart';

/// Der einzige Bildschirm der App: das Spiel als Hintergrund, darüber je nach
/// Zustand Hauptmenü, Spielanzeige, Tutorial, Pause oder Ergebnis. Dadurch
/// gibt es zwischen den Zuständen keine Ladezeiten.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.showFps = false,
    this.seed,
    this.autoplay = false,
  });
  final bool showFps;
  final int? seed;

  /// Testhilfe: überspringt das Menü und spielt selbst (ohne Ton, ohne
  /// die gespeicherte Statistik zu verändern).
  final bool autoplay;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final Settings _settings = Settings();
  final AppFlow _flow = AppFlow();
  TutorialProgress? _tutorial;
  late final DeviceFeedback _deviceFeedback = DeviceFeedback(_settings);
  late final GameFeedback _feedback = widget.autoplay
      ? SilentFeedback()
      : _deviceFeedback;
  late final FlipstackGame _game = FlipstackGame(
    store: widget.autoplay ? MemoryStatsStore() : LocalStatsStore(),
    showFps: widget.showFps,
    seed: widget.seed,
    autoplay: widget.autoplay,
    feedback: _feedback,
    onEvent: _onGameEvent,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.load();
    if (!widget.autoplay) _deviceFeedback.init();
    _game.assetsReady.addListener(_onReady);
    _game.hud.addListener(_onHud);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.assetsReady.removeListener(_onReady);
    _game.hud.removeListener(_onHud);
    super.dispose();
  }

  void _onReady() {
    if (!_game.assetsReady.value) return;
    setState(() {
      _flow.go(AppState.mainMenu);
      if (widget.autoplay) _flow.go(AppState.playing);
    });
  }

  /// Runde beendet: Ergebnis zeigen.
  void _onHud() {
    if (_game.hud.value.result != null && _flow.state != AppState.gameOver) {
      if (_tutorial != null) _finishTutorial();
      setState(() => _flow.go(AppState.gameOver));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App verlässt den Vordergrund: laufende Runde pausieren.
    if (state != AppLifecycleState.resumed && _flow.pauseIfActive()) {
      _game.paused = true;
      if (mounted) setState(() {});
    }
  }

  void _play() {
    _feedback.tap();
    setState(() {
      if (_settings.tutorialDone) {
        _tutorial = null;
        _flow.go(AppState.playing);
      } else {
        _tutorial = TutorialProgress();
        _flow.go(AppState.tutorial);
      }
      _game.restart();
    });
  }

  void _onGameEvent(GameEvent e) {
    final t = _tutorial;
    if (t == null) return;
    final advanced = switch (e) {
      GameEvent.moved => t.onMoved(),
      GameEvent.placed => t.onPlaced(),
      GameEvent.rotated => t.onRotated(),
    };
    if (advanced && mounted) setState(() {});
  }

  void _finishTutorial() {
    _tutorial?.skip();
    _tutorial = null;
    _settings.tutorialDone = true;
  }

  void _endTutorial() {
    _feedback.tap();
    setState(() {
      _finishTutorial();
      _flow.go(AppState.playing);
    });
  }

  void _pause() {
    _feedback.tap();
    if (_flow.go(AppState.paused)) {
      _game.paused = true;
      setState(() {});
    }
  }

  void _resume() {
    _feedback.tap();
    if (_flow.resume()) {
      _game.paused = false;
      setState(() {});
    }
  }

  void _restart() {
    _feedback.tap();
    setState(() {
      if (_tutorial != null) _finishTutorial();
      _flow.go(AppState.playing);
      _game.paused = false;
      _game.restart();
    });
  }

  void _home() {
    _feedback.tap();
    setState(() {
      if (_tutorial != null) _finishTutorial();
      _flow.go(AppState.mainMenu);
      _game.paused = false;
      _game.showMenu();
    });
  }

  bool get _inRound =>
      _flow.state == AppState.playing || _flow.state == AppState.tutorial;

  @override
  Widget build(BuildContext context) {
    _game.safeTop = MediaQuery.paddingOf(context).top;
    final state = _flow.state;
    return Scaffold(
      backgroundColor: const Color(0xFFEFE6D6),
      body: Stack(
        children: [
          // Ein Finger: ziehen = verschieben, tippen = ablegen
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _inRound ? (_) => _game.dragStart() : null,
            onPanUpdate: _inRound ? (d) => _game.dragUpdate(d.delta) : null,
            onTap: _inRound ? _game.drop : null,
            child: GameWidget(game: _game),
          ),
          if (state == AppState.mainMenu)
            HomeOverlay(
              stats: _game.stats,
              onPlay: _play,
              onSettings: () {
                _feedback.tap();
                showSettingsSheet(
                  context,
                  settings: _settings,
                  stats: _game.stats,
                  onTap: _feedback.tap,
                );
              },
            ),
          if (_inRound || state == AppState.paused)
            ValueListenableBuilder<HudState>(
              valueListenable: _game.hud,
              builder: (context, h, _) => GameHud(
                hud: h,
                onRotate: _game.rotate,
                onDrop: _game.drop,
                onPause: _pause,
                tutorial: state == AppState.tutorial ? _tutorial?.step : null,
              ),
            ),
          if (state == AppState.tutorial && _tutorial != null) ...[
            if (_tutorial!.step == TutorialStep.move) const SwipeHint(),
            TutorialCard(
              step: _tutorial!.step,
              onConfirm: _endTutorial,
              onSkip: _endTutorial,
            ),
          ],
          if (state == AppState.paused)
            PauseOverlay(
              settings: _settings,
              onResume: _resume,
              onRestart: _restart,
              onHome: _home,
            ),
          if (state == AppState.gameOver && _game.hud.value.result != null)
            ResultsCard(
              result: _game.hud.value.result!,
              game: _game,
              onRestart: _restart,
              onHome: _home,
            ),
        ],
      ),
    );
  }
}
