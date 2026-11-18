import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/core/game_session.dart';
import 'game/flipstack_game.dart';

// Debug-Schalter: --dart-define=FS_FPS=true  (FPS-Anzeige)
//                 --dart-define=FS_AUTOPLAY=true  (spielt selbst, für Tests)
//                 --dart-define=FS_SEED=7    (feste Bausteinfolge)
const _fps = bool.fromEnvironment('FS_FPS');
const _seed = int.fromEnvironment('FS_SEED', defaultValue: -1);
const _autoplay = bool.fromEnvironment('FS_AUTOPLAY');

const _navy = Color(0xFF202B38);
const _cream = Color(0xFFF2EEE5);
const _mint = Color(0xFF35B6A4);
const _coral = Color(0xFFF27C65);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: GameScreen()),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final FlipstackGame _game = FlipstackGame(
    showFps: _fps,
    seed: _seed < 0 ? null : _seed,
    autoplay: _autoplay,
  );

  @override
  Widget build(BuildContext context) {
    _game.safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFFEFE6D6),
      body: Stack(
        children: [
          // Ein Finger: ziehen = verschieben, tippen = ablegen
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _game.dragStart(),
            onPanUpdate: (d) => _game.dragUpdate(d.delta),
            onTap: _game.drop,
            child: GameWidget(game: _game),
          ),
          ValueListenableBuilder<HudState>(
            valueListenable: _game.hud,
            builder: (context, h, _) => Stack(
              children: [
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(left: 22, top: 10, child: _Score(h)),
                      const Positioned(
                        right: 30,
                        top: 12,
                        child: Text(
                          'NÄCHSTER',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0x99202B38),
                          ),
                        ),
                      ),
                      if (h.hint != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 124,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _coral,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                h.hint!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Row(
                          children: [
                            _RoundButton(
                              icon: Icons.rotate_left_rounded,
                              onTap: () => _game.rotate(1),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _DropButton(
                                enabled: h.canDrop,
                                onTap: _game.drop,
                              ),
                            ),
                            const SizedBox(width: 14),
                            _RoundButton(
                              icon: Icons.rotate_right_rounded,
                              onTap: () => _game.rotate(-1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (h.gameOver != null) _GameOver(h, onRestart: _game.restart),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score(this.h);
  final HudState h;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${h.score}',
          style: const TextStyle(
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'HÖHE ${h.height}   ·   BESTWERT ${h.best}',
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Color(0x99202B38),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navy,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Icon(icon, color: _cream, size: 32),
        ),
      ),
    );
  }
}

class _DropButton extends StatelessWidget {
  const _DropButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _mint : const Color(0xFFB9C4C0),
      borderRadius: BorderRadius.circular(33),
      elevation: enabled ? 3 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(33),
        onTap: onTap,
        child: const SizedBox(
          height: 66,
          child: Center(
            child: Text(
              'ABLEGEN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver(this.h, {required this.onRestart});
  final HudState h;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final summit = h.gameOver == GameOverReason.summit;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66202B38),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summit ? 'GIPFEL ERREICHT' : 'KEIN PLATZ MEHR',
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: Color(0x99202B38),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${h.score}',
                  style: const TextStyle(
                    fontSize: 64,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                if (h.newBest)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Neuer Bestwert',
                      style: TextStyle(
                        color: _coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Höhe ${h.height}   ·   Bestwert ${h.best}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onRestart,
                    child: const Text(
                      'NOCHMAL',
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
