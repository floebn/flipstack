import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ads_service.dart';

/// Werbung über Google AdMob. Lädt je eine belohnte und eine Vollbildanzeige
/// im Voraus, damit sie ohne Wartezeit starten. Vor [start] passiert nichts:
/// [start] darf erst nach erteilter Einwilligung aufgerufen werden.
class AdMobAds extends AdsService {
  AdMobAds(this.ids);

  final AdUnitIds ids;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _started = false;
  bool _loadingRewarded = false, _loadingInterstitial = false;
  int _rewardedFailures = 0, _interstitialFailures = 0;

  @override
  bool get rewardedReady => _rewarded != null;

  /// Startet das Werbe-SDK und lädt die ersten Anzeigen.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await MobileAds.instance.initialize();
      debugPrint('FLIPSTACK werbung: SDK gestartet');
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('FLIPSTACK werbung: Start fehlgeschlagen: $e');
    }
  }

  /// Nächster Ladeversuch nach einem Fehler: 20 s, 40 s, 80 s ... höchstens
  /// 10 min. Ohne Netz soll das Gerät nicht dauernd anfragen.
  Duration _backoff(int failures) => Duration(
    seconds: (20 * (1 << (failures - 1).clamp(0, 5))).clamp(20, 600),
  );

  void _loadRewarded() {
    if (!_started || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedFailures = 0;
          _rewarded = ad;
          debugPrint('FLIPSTACK werbung: belohnte Anzeige bereit');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          _rewardedFailures++;
          debugPrint(
            'FLIPSTACK werbung: belohnte Anzeige nicht geladen: '
            '${error.code} ${error.message}',
          );
          Timer(_backoff(_rewardedFailures), _loadRewarded);
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (!_started || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialFailures = 0;
          _interstitial = ad;
          debugPrint('FLIPSTACK werbung: Vollbildanzeige bereit');
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          _interstitialFailures++;
          debugPrint(
            'FLIPSTACK werbung: Vollbildanzeige nicht geladen: '
            '${error.code} ${error.message}',
          );
          Timer(_backoff(_interstitialFailures), _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded(RewardedPlacement placement) {
    final ad = _rewarded;
    if (ad == null) return Future.value(false);
    _rewarded = null;
    notifyListeners();
    final done = Completer<bool>();
    var earned = false;
    void finish() {
      ad.dispose();
      if (!done.isCompleted) done.complete(earned);
      _loadRewarded();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint(
          'FLIPSTACK werbung: Anzeige nicht gezeigt: ${error.message}',
        );
        finish();
      },
    );
    // Die Belohnung gibt es nur, wenn das SDK sie meldet; sie wird beim
    // Schliessen der Anzeige weitergegeben.
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Future<bool> showInterstitial() {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return Future.value(false);
    }
    _interstitial = null;
    final done = Completer<bool>();
    var shown = false;
    void finish() {
      ad.dispose();
      if (!done.isCompleted) done.complete(shown);
      _loadInterstitial();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => shown = true,
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint(
          'FLIPSTACK werbung: Anzeige nicht gezeigt: ${error.message}',
        );
        finish();
      },
    );
    ad.show();
    return done.future;
  }
}
