import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/game_screen.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      ),
    ),
  );
}
