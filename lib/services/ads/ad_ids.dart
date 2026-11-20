import 'dart:io' show Platform;

/// Kennungen der Anzeigenblöcke. Sie sind keine Geheimnisse, aber: In der
/// eigenen App darf nie auf echte Anzeigen getippt werden, Google wertet das
/// als Betrug. Deshalb laufen alle Builds mit Googles öffentlichen
/// Testanzeigen, solange nicht ausdrücklich `--dart-define=FS_ADS=live`
/// gesetzt ist (Veröffentlichung).
class AdUnitIds {
  const AdUnitIds({required this.rewarded, required this.interstitial});
  final String rewarded, interstitial;

  // Googles Testanzeigen: https://developers.google.com/admob/flutter/test-ads
  static const _testIos = AdUnitIds(
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _testAndroid = AdUnitIds(
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
  );

  static const _liveIos = AdUnitIds(
    rewarded: 'ca-app-pub-7935072072786523/3104223098',
    interstitial: 'ca-app-pub-7935072072786523/7259090522',
  );

  /// Anzeigenblöcke für diese Plattform. Für Android gibt es noch keine
  /// echten Blöcke; dort bleiben es die Testanzeigen.
  static AdUnitIds forPlatform({required bool live}) {
    if (Platform.isIOS) return live ? _liveIos : _testIos;
    return _testAndroid;
  }
}
