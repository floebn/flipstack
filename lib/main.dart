import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/core/game_session.dart';
import 'game/core/piece.dart';
import 'game/flipstack_game.dart';
import 'services/storage/stats_store.dart';

// Debug-Schalter: --dart-define=FS_FPS=true       FPS-Anzeige
//                 --dart-define=FS_AUTOPLAY=true  spielt selbst (für Tests)
//                 --dart-define=FS_SEED=7         feste Bausteinfolge
const _fps = bool.fromEnvironment('FS_FPS');
const _seed = int.fromEnvironment('FS_SEED', defaultValue: -1);
const _autoplay = bool.fromEnvironment('FS_AUTOPLAY');

const _navy = Color(0xFF202B38);
const _cream = Color(0xFFF2EEE5);
const _mint = Color(0xFF35B6A4);
const _coral = Color(0xFFF27C65);
const _amber = Color(0xFFF1BD58);
const _muted = Color(0x99202B38);

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
    // Testläufe mit Autoplay verändern die gespeicherte Statistik nicht.
    store: _autoplay ? MemoryStatsStore() : LocalStatsStore(),
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
            builder: (context, h, _) {
              final over = h.result != null;
              return Stack(
                children: [
                  SafeArea(
                    child: Stack(
                      children: [
                        if (!over)
                          Positioned(left: 22, top: 10, child: _Score(h)),
                        if (!over)
                          const Positioned(
                            right: 30,
                            top: 12,
                            child: Text('NÄCHSTER', style: _label),
                          ),
                        if (!over && (h.hint != null || h.warning != null))
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 104,
                            child: Center(
                              child: _Chip(
                                h.hint ?? h.warning!,
                                color: h.hint != null ? _coral : _amber,
                                textColor: h.hint != null
                                    ? Colors.white
                                    : _navy,
                              ),
                            ),
                          ),
                        if (!over)
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
                  if (over)
                    _GameOver(h.result!, game: _game, onRestart: _game.restart),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

const _label = TextStyle(
  fontSize: 10.5,
  letterSpacing: 1.3,
  fontWeight: FontWeight.w700,
  color: _muted,
);

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.color, this.textColor = Colors.white});
  final String text;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
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
        Text('HÖHE ${h.height}   ·   BESTWERT ${h.best}', style: _label),
        const SizedBox(height: 8),
        // Combo: zeigt den Multiplikator der nächsten sauberen Ablage
        AnimatedOpacity(
          opacity: h.combo >= 1 ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: _Chip(
            'COMBO ${h.combo}   ×${h.multiplier.toStringAsFixed(1).replaceAll('.', ',')}',
            color: _navy,
            textColor: _amber,
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

/// Ergebnis der Runde. Liegt im unteren Bildschirmdrittel, damit der fertige
/// Turm darüber sichtbar bleibt.
class _GameOver extends StatelessWidget {
  const _GameOver(this.r, {required this.game, required this.onRestart});
  final RoundResult r;
  final FlipstackGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final summit = r.reason == GameOverReason.summit;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - t)),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33202B38),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summit ? 'GIPFEL ERREICHT' : 'KEIN PLATZ MEHR',
                    style: _label.copyWith(fontSize: 12.5, letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${r.score}',
                    style: const TextStyle(
                      fontSize: 60,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  Text(
                    r.newBest
                        ? 'Neuer Bestwert'
                        : 'Bestwert ${r.stats.bestScore}',
                    style: TextStyle(
                      color: r.newBest ? _coral : _muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (r.blockedPiece != null) ...[
                    const SizedBox(height: 14),
                    _BlockedInfo(r, game),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat('HÖHE', '${r.height}'),
                      _Stat('STEINE', '${r.pieces}'),
                      _Stat('COMBO', '${r.bestCombo}'),
                      _Stat('Ø PUNKTE', '${r.stats.averageScore}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
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
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: _label),
      ],
    );
  }
}

/// Erklärt das Spielende: zeigt den Baustein, der nirgends passte, und warum.
class _BlockedInfo extends StatelessWidget {
  const _BlockedInfo(this.r, this.game);
  final RoundResult r;
  final FlipstackGame game;

  @override
  Widget build(BuildContext context) {
    final why = switch (r.blockCause!) {
      BlockCause.tooUneven => 'An jeder Stelle wäre der Turm mehr als 4 Ebenen ungleich hoch geworden.',
      BlockCause.unsupported => 'An jeder Stelle hätte er zu wenig aufgelegen.',
      BlockCause.both => 'Er hätte zu wenig aufgelegen oder den Turm mehr als 4 Ebenen ungleich hoch gemacht.',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0x14202B38),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 58,
            child: CustomPaint(painter: _PiecePainter(game, r.blockedPiece!)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Dieser Stein passte nirgends. ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: why),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.3, color: _navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.game, this.shape);
  final FlipstackGame game;
  final PieceShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final span = shape.width + shape.depth;
    game.paintPiece(
      canvas,
      shape,
      size.center(Offset.zero),
      (size.width / (span * 0.75)).clamp(8, 17),
    );
  }

  @override
  bool shouldRepaint(_PiecePainter old) => old.shape != shape;
}
