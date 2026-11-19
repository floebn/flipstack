import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../features/gameplay/gameplay_overlays.dart';
import '../features/home/home_overlay.dart';
import '../features/rewards/rewards_ui.dart';
import '../features/shop/shop_panel.dart';
import '../features/settings/settings_sheet.dart';
import '../game/flipstack_game.dart';
import '../game/meta/rewards.dart';
import '../services/feedback/game_feedback.dart';
import '../services/storage/profile_store.dart';
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
    this.testCoins = 0,
    this.testLook = '',
  });
  final bool showFps;
  final int? seed;

  /// Testhilfe: überspringt das Menü und spielt selbst (ohne Ton, ohne
  /// die gespeicherte Statistik zu verändern).
  final bool autoplay;

  /// Testhilfe: Belohnungsstand mit so vielen Münzen, nur im Speicher.
  final int testCoins;

  /// Testhilfe: Kennungen von Freischaltungen (durch Komma getrennt), die
  /// ohne Kauf gezeigt werden.
  final String testLook;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final Settings _settings = Settings();
  final AppFlow _flow = AppFlow();
  TutorialProgress? _tutorial;

  /// Shop liegt über dem Hauptmenü; der Beispielturm dient als Bühne.
  bool _shopOpen = false;
  late final DeviceFeedback _deviceFeedback = DeviceFeedback(_settings);
  late final GameFeedback _feedback = widget.autoplay
      ? SilentFeedback()
      : _deviceFeedback;
  late final ProfileController _profile = ProfileController(
    widget.testCoins > 0
        ? MemoryProfileStore(Profile(coins: widget.testCoins))
        : widget.autoplay
        ? MemoryProfileStore()
        : LocalProfileStore(),
  );
  late final FlipstackGame _game = FlipstackGame(
    profile: _profile,
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
    _profile.addListener(_onProfile);
  }

  void _onProfile() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.assetsReady.removeListener(_onReady);
    _game.hud.removeListener(_onHud);
    _profile.removeListener(_onProfile);
    super.dispose();
  }

  void _onReady() {
    if (!_game.assetsReady.value) return;
    if (widget.testLook.isNotEmpty) {
      _game.previewLook({
        for (final id in widget.testLook.split(','))
          if (Cosmetics.byId[id] != null) Cosmetics.byId[id]!.category: id,
      });
    }
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
    // Zurück im Vordergrund: neuer Tag bringt neue Aufgaben.
    if (state == AppLifecycleState.resumed) _profile.refresh();
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
      _profile.refresh();
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
          if (state == AppState.mainMenu && _shopOpen)
            ShopPanel(
              controller: _profile,
              game: _game,
              onTap: _feedback.tap,
              onClose: () {
                _feedback.tap();
                setState(() => _shopOpen = false);
              },
            ),
          if (state == AppState.mainMenu && !_shopOpen)
            HomeOverlay(
              stats: _game.stats,
              profile: _profile.profile,
              onQuests: () {
                _feedback.tap();
                showQuestsSheet(context, _profile);
              },
              onShop: () {
                _feedback.tap();
                setState(() => _shopOpen = true);
              },
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
              profile: _profile.profile,
              game: _game,
              onRestart: _restart,
              onHome: _home,
            ),
        ],
      ),
    );
  }
}
