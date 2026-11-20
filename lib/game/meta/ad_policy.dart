/// Regeln für Vollbildwerbung zwischen Runden (Masterbrief 8.2). Reines Dart,
/// ohne Werbe-SDK, damit die Regeln testbar sind.
///
/// Belohnte Werbung ist immer freiwillig und unterliegt diesen Regeln nicht.
class AdConfig {
  const AdConfig({
    this.firstAfterRounds = 3,
    this.everyRounds = 4,
    this.minSecondsBetween = 180,
    this.minSecondsAfterStart = 90,
    this.minRoundSeconds = 40,
  });

  /// Erste Vollbildwerbung frühestens nach so vielen beendeten Runden.
  final int firstAfterRounds;

  /// Danach höchstens nach jeder so-vielten beendeten Runde.
  final int everyRounds;

  /// Mindestabstand zwischen zwei Vollbildwerbungen in Sekunden.
  final int minSecondsBetween;

  /// Keine Werbung, solange die App noch nicht so lange offen ist.
  final int minSecondsAfterStart;

  /// Nach einer kürzeren Runde gibt es keine Werbung: Wer früh scheitert,
  /// soll nicht zusätzlich unterbrochen werden.
  final int minRoundSeconds;
}

class AdPolicy {
  AdPolicy([this.config = const AdConfig()]);

  final AdConfig config;

  int _rounds = 0;
  int _roundsSinceAd = 0;
  double? _lastAdAt;

  /// Beendete Runden seit dem Öffnen der App.
  int get rounds => _rounds;

  /// Meldet eine beendete Runde und entscheidet, ob danach eine Vollbild-
  /// werbung gezeigt werden darf. [now] sind Sekunden seit dem Öffnen der App.
  bool roundFinished({
    required double now,
    required int roundSeconds,
    bool tutorial = false,
    bool rewardedThisRound = false,
    bool adsRemoved = false,
  }) {
    _rounds++;
    _roundsSinceAd++;
    if (adsRemoved || tutorial || rewardedThisRound) return false;
    if (roundSeconds < config.minRoundSeconds) return false;
    if (now < config.minSecondsAfterStart) return false;
    final last = _lastAdAt;
    if (last == null) return _rounds >= config.firstAfterRounds;
    return _roundsSinceAd >= config.everyRounds &&
        now - last >= config.minSecondsBetween;
  }

  /// Die zuletzt gemeldete Runde geht nach einer zweiten Chance weiter und
  /// zählt erst an ihrem wirklichen Ende.
  void roundResumed() {
    if (_rounds > 0) _rounds--;
    if (_roundsSinceAd > 0) _roundsSinceAd--;
  }

  /// Die Werbung wurde tatsächlich gezeigt.
  void interstitialShown(double now) {
    _lastAdAt = now;
    _roundsSinceAd = 0;
  }
}
