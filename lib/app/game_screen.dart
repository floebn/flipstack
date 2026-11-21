import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/fs_colors.dart';

import '../features/gameplay/gameplay_overlays.dart';
import '../features/home/home_overlay.dart';
import '../features/rewards/rewards_ui.dart';
import '../features/shop/shop_panel.dart';
import '../features/settings/settings_sheet.dart';
import '../game/flipstack_game.dart';
import '../game/meta/rewards.dart';
import '../game/meta/ad_policy.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ads/ad_ids.dart';
import '../services/ads/admob_ads.dart';
import '../services/ads/ads_service.dart';
import '../services/ads/consent.dart';
import '../features/premium/remove_ads_sheet.dart';
import '../services/feedback/game_feedback.dart';
import '../services/purchases/purchase_service.dart';
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
    this.adsMode = '',
    this.fakePurchases = false,
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

  /// Werbung: '' = Googles Testanzeigen, 'fake' = Platzhalter ohne SDK,
  /// 'off' = keine, 'live' = echte Anzeigen.
  final String adsMode;

  /// Testhilfe: Kauf "Werbefrei" als Platzhalter ohne Store.
  final bool fakePurchases;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final Settings _settings = Settings();
  final AppFlow _flow = AppFlow();
  TutorialProgress? _tutorial;

  /// Werbung: bis das Werbe-SDK eingebunden ist, entweder keine oder ein
  /// Platzhalter zum Testen der Abläufe.
  late final AdsService _ads = switch (widget.adsMode) {
    'fake' => FakeAds(() => context),
    'off' => NoAds(),
    _ =>
      (widget.autoplay && widget.adsMode.isEmpty) || !_isPhone
          ? NoAds()
          : AdMobAds(AdUnitIds.forPlatform(live: widget.adsMode == 'live')),
  };
  final ConsentManager _consent = ConsentManager();

  /// Die Einstellungen zeigen einen Eintrag, mit dem sich die Entscheidung
  /// zur Werbung ändern lässt.
  bool _privacyOptions = false;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Fragt die Einwilligung ab und startet erst danach das Werbe-SDK. Ohne
  /// Einwilligung bleibt es bei keiner Werbung; das Spiel läuft normal.
  Future<void> _startAds() async {
    final ads = _ads;
    if (ads is! AdMobAds) return;
    // Nur zum Prüfen der Werbeabläufe im Debug-Build mit Testanzeigen:
    // --dart-define=FS_SKIP_CONSENT=true überspringt die Abfrage.
    const skip = bool.fromEnvironment('FS_SKIP_CONSENT');
    final testOnly = kDebugMode && skip && widget.adsMode != 'live';
    if (testOnly || await _consent.gather()) await ads.start();
    final options = await _consent.privacyOptionsRequired();
    if (mounted) setState(() => _privacyOptions = options);
  }

  Future<void> _changePrivacyOptions() async {
    await _consent.showPrivacyOptions();
    await _startAds();
  }

  /// Regeln für Vollbildwerbung. Der Zählerstand wird gespeichert und beim
  /// Start geladen, damit ein Neustart der App ihn nicht zurücksetzt.
  static const _adStateKey = 'ad_policy_v1';
  AdPolicy _adPolicy = AdPolicy(sessionStart: _epoch);

  static double get _epoch => DateTime.now().millisecondsSinceEpoch / 1000;

  Future<void> _loadAdPolicy() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _adStateKey,
      );
      if (raw == null) return;
      _adPolicy = AdPolicy(
        state: AdPolicyState.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        sessionStart: _adPolicy.sessionStart,
      );
    } catch (_) {}
  }

  void _saveAdPolicy() {
    SharedPreferences.getInstance()
        .then((p) => p.setString(_adStateKey, jsonEncode(_adPolicy.state)))
        .catchError((_) => false);
  }

  /// Einmaliger Kauf "Werbefrei": entfernt die Vollbildwerbung zwischen den
  /// Runden. Freiwillige, belohnte Werbung bleibt.
  late final PurchaseService _purchases = widget.fakePurchases
      ? FakePurchases()
      : widget.autoplay || !_isPhone
      ? NoPurchases()
      : StorePurchases();

  void _openRemoveAds() {
    _feedback.tap();
    showRemoveAdsSheet(context, _purchases, onTap: _feedback.tap);
  }

  bool _rewardedThisRound = false;
  bool _coinsDoubled = false;
  bool _interstitialDue = false;
  bool _adRunning = false;

  /// Münzen wurden verdoppelt und danach die Runde fortgesetzt: Die
  /// Verdopplung gilt dann für das wirkliche Ende der Runde, ohne zweite
  /// Werbung.
  bool _doublePending = false;

  double get _now => _epoch;

  /// Zweite Chance gegen freiwillige Werbung, höchstens einmal je Runde.
  Future<void> _revive() async {
    if (_adRunning) return;
    _adRunning = true;
    final ok = await _ads.showRewarded(RewardedPlacement.revive);
    _adRunning = false;
    if (!ok || !mounted) return;
    _rewardedThisRound = true;
    final doubled = _coinsDoubled;
    if (_game.revive()) {
      _doublePending = doubled;
      _coinsDoubled = false;
      _saveRound();
      _adPolicy.roundResumed();
      _saveAdPolicy();
      _interstitialDue = false;
      setState(() => _flow.go(AppState.playing));
    }
  }

  /// Rundenmünzen gegen freiwillige Werbung verdoppeln.
  Future<void> _doubleCoins(RoundResult r) async {
    if (_adRunning || _coinsDoubled) return;
    _adRunning = true;
    final ok = await _ads.showRewarded(RewardedPlacement.doubleCoins);
    _adRunning = false;
    if (!ok || !mounted) return;
    _rewardedThisRound = true;
    _profile.addBonus(r.rewards.roundCoins + r.rewards.stageCoins);
    setState(() => _coinsDoubled = true);
  }

  /// Zwischen zwei Runden: Vollbildwerbung, falls die Regeln sie erlauben.
  Future<void> _betweenRounds() async {
    if (!_interstitialDue) return;
    _interstitialDue = false;
    if (_purchases.adsRemoved) return;
    if (await _ads.showInterstitial()) {
      _adPolicy.interstitialShown(_now);
      _saveAdPolicy();
    }
  }

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
    _ads.addListener(_onProfile);
    _purchases.addListener(_onProfile);
    _purchases.load();
    _loadSavedRound();
    if (!widget.autoplay || widget.adsMode.isNotEmpty) _loadAdPolicy();
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
    _ads.removeListener(_onProfile);
    _purchases.removeListener(_onProfile);
    _purchases.dispose();
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
    // Erst wenn das Hauptmenü steht: Einwilligung, dann Werbung
    _startAds();
  }

  /// Runde beendet: Ergebnis zeigen.
  void _onHud() {
    if (_game.hud.value.result != null && _flow.state != AppState.gameOver) {
      final tutorial = _tutorial != null;
      if (tutorial) _finishTutorial();
      _clearSavedRound();
      final r = _game.hud.value.result!;
      // Nur das wirkliche Ende der Runde zählt (nicht vor einer zweiten Chance,
      // die erst danach angeboten wird: dann zählt diese Meldung doppelt nicht,
      // weil belohnte Werbung die Vollbildwerbung für diese Runde sperrt).
      _interstitialDue = _adPolicy.roundFinished(
        now: _now,
        roundSeconds: r.seconds,
        tutorial: tutorial,
        rewardedThisRound: _rewardedThisRound,
        adsRemoved: _purchases.adsRemoved,
      );
      _saveAdPolicy();
      if (_doublePending) {
        _doublePending = false;
        _coinsDoubled = true;
        _profile.addBonus(r.rewards.roundCoins + r.rewards.stageCoins);
      }
      setState(() => _flow.go(AppState.gameOver));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zurück im Vordergrund: neuer Tag bringt neue Aufgaben.
    if (state == AppLifecycleState.resumed) _profile.refresh();
    // App verlässt den Vordergrund: laufende Runde pausieren.
    if (state != AppLifecycleState.resumed) _saveRound();
    if (state != AppLifecycleState.resumed && _flow.pauseIfActive()) {
      _game.paused = true;
      if (mounted) setState(() {});
    }
  }

  // ------------------------------------------------ Runde fortsetzen

  static const _roundKey = 'saved_round_v1';

  /// Zuletzt gespeicherte, noch nicht beendete Runde.
  Map<String, dynamic>? _savedRound;

  bool get _persistRounds => !widget.autoplay;

  Future<void> _loadSavedRound() async {
    if (!_persistRounds) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_roundKey);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _savedRound = saved);
    } catch (_) {}
  }

  /// Speichert die laufende Runde (nach jedem Zug, bei Pause und wenn die App
  /// den Vordergrund verlässt). Das Tutorial wird nicht gespeichert.
  void _saveRound() {
    if (!_persistRounds || _tutorial != null) return;
    final snap = _game.snapshot();
    if (snap == null) return;
    _savedRound = snap;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_roundKey, jsonEncode(snap)))
        .catchError((_) => false);
  }

  void _clearSavedRound() {
    if (_savedRound == null && !_persistRounds) return;
    _savedRound = null;
    SharedPreferences.getInstance()
        .then((p) => p.remove(_roundKey))
        .catchError((_) => false);
  }

  /// Höhe und Punkte der gespeicherten Runde für das Hauptmenü.
  ({int height, int score})? get _savedInfo {
    final session = _savedRound?['session'];
    if (session is! Map) return null;
    var height = 0;
    final cells = session['cells'];
    if (cells is List) {
      for (final c in cells) {
        if (c is List && c.length > 2 && c[2] is int && c[2] + 1 > height) {
          height = (c[2] as int) + 1;
        }
      }
    }
    final score = session['score'];
    return (height: height, score: score is int ? score : 0);
  }

  void _continueRound() {
    final saved = _savedRound;
    if (saved == null) return;
    _feedback.tap();
    if (_game.resumeRound(saved)) {
      setState(() {
        _tutorial = null;
        _rewardedThisRound = false;
        _coinsDoubled = false;
        _doublePending = false;
        _flow.go(AppState.playing);
      });
    } else {
      // Nicht lesbar (z. B. nach einem Update): verwerfen und neu beginnen
      _clearSavedRound();
      _play();
    }
  }

  void _play() {
    _feedback.tap();
    _clearSavedRound();
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
    if (t == null) {
      if (e != GameEvent.moved) _saveRound();
      return;
    }
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
    _saveRound();
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

  Future<void> _restart() async {
    _feedback.tap();
    _clearSavedRound();
    if (_flow.state == AppState.gameOver) {
      if (_rewardedThisRound) _interstitialDue = false;
      await _betweenRounds();
      if (!mounted) return;
    }
    _rewardedThisRound = false;
    _coinsDoubled = false;
    _doublePending = false;
    setState(() {
      if (_tutorial != null) _finishTutorial();
      _flow.go(AppState.playing);
      _game.paused = false;
      _game.restart();
    });
  }

  Future<void> _home() async {
    _feedback.tap();
    // Aus der Pause ins Menü: Die Runde bleibt zum Fortsetzen erhalten
    _saveRound();
    if (_flow.state == AppState.gameOver) {
      if (_rewardedThisRound) _interstitialDue = false;
      await _betweenRounds();
      if (!mounted) return;
    }
    _rewardedThisRound = false;
    _coinsDoubled = false;
    _doublePending = false;
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
    // Dunkler Hintergrund: helle Schrift und helle Statusleiste
    return ValueListenableBuilder<bool>(
      valueListenable: fsDarkBackground,
      builder: (context, dark, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: _buildScreen(context),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
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
              savedRound: _savedInfo,
              onContinue: _continueRound,
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
                  adsRemoved: _purchases.adsRemoved,
                  removeAdsPrice: _purchases.price,
                  onRemoveAds: _purchases is NoPurchases
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _openRemoveAds();
                        },
                  onPrivacyOptions: _privacyOptions
                      ? _changePrivacyOptions
                      : null,
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
              onRevive: _ads.rewardedReady && _game.hud.value.result!.canRevive
                  ? _revive
                  : null,
              onDoubleCoins:
                  _ads.rewardedReady &&
                      !_coinsDoubled &&
                      _game.hud.value.result!.rewards.roundCoins > 0
                  ? () => _doubleCoins(_game.hud.value.result!)
                  : null,
              coinsDoubled: _coinsDoubled,
              // Hinweis auf den Kauf nur, wenn überhaupt Werbung läuft
              onRemoveAds:
                  _ads is! NoAds &&
                      _purchases is! NoPurchases &&
                      !_purchases.adsRemoved
                  ? _openRemoveAds
                  : null,
            ),
        ],
      ),
    );
  }
}
