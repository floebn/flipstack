import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/game_screen.dart';

// Debug-Schalter: --dart-define=FS_FPS=true       FPS-Anzeige
//                 --dart-define=FS_AUTOPLAY=true  spielt selbst (für Tests)
//                 --dart-define=FS_SEED=7         feste Bausteinfolge
const _fps = bool.fromEnvironment('FS_FPS');
const _seed = int.fromEnvironment('FS_SEED', defaultValue: -1);
const _autoplay = bool.fromEnvironment('FS_AUTOPLAY');

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
      ),
    ),
  );
}
