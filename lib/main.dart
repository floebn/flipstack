import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/game_screen.dart';
import 'features/splash/splash_overlay.dart';
import 'l10n/tr.dart';

// Debug-Schalter: --dart-define=FS_FPS=true       FPS-Anzeige
//                 --dart-define=FS_AUTOPLAY=true  spielt selbst (für Tests)
//                 --dart-define=FS_SEED=7         feste Bausteinfolge
//                 --dart-define=FS_COINS=3000     Testkonto mit Münzen (wird nicht gespeichert)
//                 --dart-define=FS_START_HEIGHT=9 Runde beginnt mit vollen Ebenen
const _fps = bool.fromEnvironment('FS_FPS');
const _seed = int.fromEnvironment('FS_SEED', defaultValue: -1);
const _autoplay = bool.fromEnvironment('FS_AUTOPLAY');
const _coins = int.fromEnvironment('FS_COINS');

// --dart-define=FS_LOOK=mat_ice,blocks_arctic  zeigt Freischaltungen ohne Kauf
const _look = String.fromEnvironment('FS_LOOK');

// Werbung: ohne Schalter Googles Testanzeigen.
//   --dart-define=FS_ADS=fake  Platzhalter ohne Werbe-SDK (Abläufe prüfen)
//   --dart-define=FS_ADS=off   keine Werbung
//   --dart-define=FS_ADS=live  echte Anzeigen (nur für die Veröffentlichung)
const _ads = String.fromEnvironment('FS_ADS');

// --dart-define=FS_IAP=fake  Kauf "Werbefrei" als Platzhalter ohne Store
const _iap = String.fromEnvironment('FS_IAP');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Deutsch auf deutschsprachigen Geräten, sonst Englisch.
  // Zum Testen: --dart-define=FS_LANG=en
  const forced = String.fromEnvironment('FS_LANG');
  setLanguageFromCode(
    forced.isNotEmpty
        ? forced
        : PlatformDispatcher.instance.locale.languageCode,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Die Bilder des Startbildschirms liegen vor dem ersten Bild bereit, sonst
  // flackert der Übergang vom nativen Startbild. Im Selbstspiel entfällt er.
  SplashArt? splash;
  if (!_autoplay) {
    try {
      splash = await SplashArt.load();
    } catch (e) {
      debugPrint('Startbildschirm nicht geladen: $e');
    }
  }
  runApp(
    MaterialApp(
      title: 'FLIPSTACK',
      debugShowCheckedModeBanner: false,
      home: GameScreen(
        showFps: _fps,
        seed: _seed < 0 ? null : _seed,
        autoplay: _autoplay,
        testCoins: _coins,
        testLook: _look,
        adsMode: _ads,
        fakePurchases: _iap == 'fake',
        splash: splash,
      ),
    ),
  );
}
