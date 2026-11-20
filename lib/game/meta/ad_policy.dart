/// Regeln für Vollbildwerbung zwischen Runden (Masterbrief 8.2). Reines Dart,
/// ohne Werbe-SDK, damit die Regeln testbar sind.
///
/// Belohnte Werbung ist immer freiwillig und unterliegt diesen Regeln nicht.
class AdConfig {
  const AdConfig({
    this.firstAfterRounds = 3,
    this.everyRounds = 2,
    this.minSecondsBetween = 240,
    this.minSecondsAfterStart = 60,
    this.minRoundSeconds = 40,
  });

  /// Neue Spieler sehen die erste Vollbildwerbung frühestens nach so vielen
  /// beendeten Runden (über alle Sitzungen gezählt).
  final int firstAfterRounds;

  /// Danach höchstens nach jeder so-vielten beendeten Runde. Runden dauern
  /// meist mehrere Minuten; "jede vierte" wäre dann seltener als alle 20 min.
  final int everyRounds;

  /// Mindestabstand zwischen zwei Vollbildwerbungen in Sekunden. Schützt vor
  /// Werbung in kurzer Folge, wenn Runden schnell enden.
  final int minSecondsBetween;

  /// Keine Werbung, solange die App noch nicht so lange offen ist.
  final int minSecondsAfterStart;

  /// Nach einer kürzeren Runde gibt es keine Werbung: Wer früh scheitert,
  /// soll nicht zusätzlich unterbrochen werden.
  final int minRoundSeconds;
}

/// Zählerstand, der über Neustarts der App hinweg erhalten bleibt. Ohne ihn
/// begänne jede Sitzung wieder bei null, und häufiges Neustarten umginge die
/// Werbung.
class AdPolicyState {
  const AdPolicyState({
    this.totalRounds = 0,
    this.roundsSinceAd = 0,
    this.lastAdAt,
  });

  /// Beendete Runden insgesamt.
  final int totalRounds;

  /// Beendete Runden seit der letzten Vollbildwerbung.
  final int roundsSinceAd;

  /// Zeitpunkt der letzten Vollbildwerbung (Sekunden seit 1970) oder `null`.
  final double? lastAdAt;

  Map<String, dynamic> toJson() => {
    'totalRounds': totalRounds,
    'roundsSinceAd': roundsSinceAd,
    'lastAdAt': lastAdAt,
  };

  factory AdPolicyState.fromJson(Map<String, dynamic> j) {
    int nat(Object? v) => v is int && v >= 0 ? v : 0;
    final last = j['lastAdAt'];
    return AdPolicyState(
      totalRounds: nat(j['totalRounds']),
      roundsSinceAd: nat(j['roundsSinceAd']),
      lastAdAt: last is num && last > 0 ? last.toDouble() : null,
    );
  }
}

class AdPolicy {
  /// [sessionStart] und alle Zeitangaben sind Sekunden seit 1970.
  AdPolicy({
    this.config = const AdConfig(),
    this.state = const AdPolicyState(),
    required this.sessionStart,
  });

  final AdConfig config;
  final double sessionStart;

  /// Aktueller Zählerstand (wird von der App gespeichert).
  AdPolicyState state;

  /// Meldet eine beendete Runde und entscheidet, ob danach eine Vollbild-
  /// werbung gezeigt werden darf.
  bool roundFinished({
    required double now,
    required int roundSeconds,
    bool tutorial = false,
    bool rewardedThisRound = false,
    bool adsRemoved = false,
  }) {
    state = AdPolicyState(
      totalRounds: state.totalRounds + 1,
      roundsSinceAd: state.roundsSinceAd + 1,
      lastAdAt: state.lastAdAt,
    );
    if (adsRemoved || tutorial || rewardedThisRound) return false;
    if (roundSeconds < config.minRoundSeconds) return false;
    if (now - sessionStart < config.minSecondsAfterStart) return false;
    final last = state.lastAdAt;
    if (last == null) return state.totalRounds >= config.firstAfterRounds;
    return state.roundsSinceAd >= config.everyRounds &&
        now - last >= config.minSecondsBetween;
  }

  /// Die zuletzt gemeldete Runde geht nach einer zweiten Chance weiter und
  /// zählt erst an ihrem wirklichen Ende.
  void roundResumed() {
    state = AdPolicyState(
      totalRounds: state.totalRounds > 0 ? state.totalRounds - 1 : 0,
      roundsSinceAd: state.roundsSinceAd > 0 ? state.roundsSinceAd - 1 : 0,
      lastAdAt: state.lastAdAt,
    );
  }

  /// Die Werbung wurde tatsächlich gezeigt.
  void interstitialShown(double now) {
    state = AdPolicyState(
      totalRounds: state.totalRounds,
      roundsSinceAd: 0,
      lastAdAt: now,
    );
  }
}
