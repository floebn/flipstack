import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Einwilligung für Werbung über Googles User Messaging Platform.
///
/// Die Abfrage selbst (DSGVO-Mitteilung und, auf iOS, die Erklärung vor Apples
/// Tracking-Dialog) wird in AdMob unter "Datenschutz und Mitteilungen"
/// angelegt. Solange dort nichts veröffentlicht ist oder der Spieler nicht
/// geantwortet hat, liefert [gather] `false`, und es wird keine Werbung
/// geladen.
class ConsentManager {
  /// Fragt den Einwilligungsstatus ab, zeigt bei Bedarf die Mitteilung und
  /// meldet, ob Werbung angefragt werden darf.
  ///
  /// Streng: Lässt sich der Status nicht abrufen (kein Netz, in AdMob keine
  /// Mitteilung veröffentlicht), gibt es in dieser Sitzung keine Werbung. Im
  /// Test meldete Googles Bibliothek in genau diesem Fall "Werbung erlaubt";
  /// darauf verlässt sich die App nicht.
  Future<bool> gather() async {
    final done = Completer<void>();
    var updated = false;
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          updated = true;
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                debugPrint(
                  'FLIPSTACK einwilligung: Mitteilung nicht gezeigt: '
                  '${error.errorCode} ${error.message}',
                );
              }
              if (!done.isCompleted) done.complete();
            });
          } catch (e) {
            debugPrint('FLIPSTACK einwilligung: $e');
            if (!done.isCompleted) done.complete();
          }
        },
        (error) {
          debugPrint(
            'FLIPSTACK einwilligung: Status nicht abrufbar: '
            '${error.errorCode} ${error.message}',
          );
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 60), onTimeout: () {});
      final ok = updated && await ConsentInformation.instance.canRequestAds();
      debugPrint('FLIPSTACK einwilligung: Werbung erlaubt = $ok');
      return ok;
    } catch (e) {
      debugPrint('FLIPSTACK einwilligung: $e');
      return false;
    }
  }

  /// Der Spieler muss seine Entscheidung nachträglich ändern können; dann
  /// zeigen die Einstellungen einen Eintrag dafür.
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Öffnet die Datenschutz-Einstellungen der Werbung.
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        debugPrint('FLIPSTACK einwilligung: ${error.message}');
      }
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
