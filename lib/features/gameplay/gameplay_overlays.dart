import 'package:flutter/material.dart';

import '../../app/app_flow.dart';
import '../../game/core/game_session.dart';
import '../../game/core/piece.dart';
import '../../game/flipstack_game.dart';
import '../../services/storage/settings_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Anzeige und Bedienung während einer Runde.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.hud,
    required this.onRotate,
    required this.onDrop,
    required this.onPause,
    this.tutorial,
  });
  final HudState hud;
  final void Function(int dir) onRotate;
  final VoidCallback onDrop, onPause;

  /// Aktueller Tutorial-Schritt (hebt das passende Bedienelement hervor).
  final TutorialStep? tutorial;

  @override
  Widget build(BuildContext context) {
    final h = hud;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(left: 22, top: 10, child: _Score(h)),
          Positioned(
            right: 18,
            top: 8,
            child: RoundIconButton(
              Icons.pause_rounded,
              onTap: onPause,
              size: 42,
              color: FsColors.cream,
              iconColor: FsColors.navy,
              semanticLabel: 'Pause',
            ),
          ),
          const Positioned(
            right: 26,
            top: 62,
            child: Text('NÄCHSTER', style: fsLabel),
          ),
          if (h.notice != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: tutorial == null ? 150 : 296,
              child: Center(
                child: FsChip(
                  h.notice!,
                  color: FsColors.navy,
                  textColor: Colors.white,
                ),
              ),
            ),
          if (h.hint != null || h.warning != null)
            Positioned(
              left: 0,
              right: 0,
              // im Tutorial liegt hier die Anleitung, der Hinweis rückt darüber
              bottom: tutorial == null ? 104 : 250,
              child: Center(
                child: FsChip(
                  h.hint ?? h.warning!,
                  color: h.hint != null ? FsColors.highlight : FsColors.warning,
                  textColor: h.hint != null ? Colors.white : FsColors.navy,
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Row(
              children: [
                PulseRing(
                  active: tutorial == TutorialStep.rotate,
                  child: RoundIconButton(
                    Icons.rotate_left_rounded,
                    onTap: () => onRotate(1),
                    semanticLabel: 'Plattform nach links drehen',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: PulseRing(
                    active: tutorial == TutorialStep.drop,
                    child: PillButton(
                      'ABLEGEN',
                      onTap: onDrop,
                      enabled: h.canDrop,
                      height: 66,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                PulseRing(
                  active: tutorial == TutorialStep.rotate,
                  child: RoundIconButton(
                    Icons.rotate_right_rounded,
                    onTap: () => onRotate(-1),
                    semanticLabel: 'Plattform nach rechts drehen',
                  ),
                ),
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
            color: FsColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text('HÖHE ${h.height}   ·   BESTWERT ${h.best}', style: fsLabel),
        const SizedBox(height: 8),
        // Combo: zeigt den Multiplikator der nächsten sauberen Ablage
        AnimatedOpacity(
          opacity: h.combo >= 1 ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: FsChip(
            'COMBO ${h.combo}   ×${h.multiplier.toStringAsFixed(1).replaceAll('.', ',')}',
            color: FsColors.navy,
            textColor: FsColors.reward,
          ),
        ),
      ],
    );
  }
}

/// Kurze Anleitung in vier Schritten, die der Spieler durch Tun abschliesst.
class TutorialCard extends StatelessWidget {
  const TutorialCard({
    super.key,
    required this.step,
    required this.onConfirm,
    required this.onSkip,
  });
  final TutorialStep step;
  final VoidCallback onConfirm, onSkip;

  static const _texts = {
    TutorialStep.move: (
      'Verschieben',
      'Ziehe mit einem Finger, um den Stein zu bewegen.',
    ),
    TutorialStep.drop: (
      'Ablegen',
      'Tippe auf ABLEGEN – oder einfach irgendwo auf den Bildschirm.',
    ),
    TutorialStep.rotate: (
      'Drehen',
      'Drehe die Plattform. Der Stein dreht sich nie mit – so änderst du, wie er liegt.',
    ),
    TutorialStep.rules: (
      'Punkte',
      'Volle Auflage gibt Bonus und Combo. Bau gleichmäßig – ein Rahmen zeigt die erlaubte Höhe.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = _texts[step];
    if (t == null) return const SizedBox.shrink();
    final index = TutorialStep.values.indexOf(step);
    return SafeArea(
      child: Align(
        // unten über den Knöpfen: dort verdeckt die Karte weder Stein noch Turm
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 104),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: FsCard(
              key: ValueKey(step),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${index + 1} / 4   ${t.$1.toUpperCase()}',
                        style: fsLabel,
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: onSkip,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Text('ÜBERSPRINGEN', style: fsLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.$2,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: FsColors.navy,
                    ),
                  ),
                  if (step == TutorialStep.rules) ...[
                    const SizedBox(height: 12),
                    PillButton("LOS GEHT'S", onTap: onConfirm, height: 48),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wischende Hand als Hinweis für den ersten Tutorial-Schritt.
class SwipeHint extends StatefulWidget {
  const SwipeHint({super.key});

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.1),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_c.value);
            return Transform.translate(
              offset: Offset(-45 + 90 * t, -22 + 44 * t),
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xCC202B38),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: FsColors.cream,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
  });
  final Settings settings;
  final VoidCallback onResume, onRestart, onHome;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x80202B38),
        child: Center(
          child: SizedBox(
            width: 310,
            child: FsCard(
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PAUSE',
                      style: fsLabel.copyWith(fontSize: 13, letterSpacing: 2.5),
                    ),
                    const SizedBox(height: 16),
                    PillButton('WEITER', onTap: onResume),
                    const SizedBox(height: 10),
                    PillButton(
                      'NEU STARTEN',
                      onTap: onRestart,
                      color: FsColors.navy,
                      textColor: FsColors.cream,
                      height: 54,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _IconToggle(
                          settings.sound
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          'Ton',
                          settings.sound,
                          () => settings.sound = !settings.sound,
                        ),
                        _IconToggle(
                          Icons.vibration_rounded,
                          'Vibration',
                          settings.haptics,
                          () => settings.haptics = !settings.haptics,
                        ),
                        _IconToggle(Icons.home_rounded, 'Menü', true, onHome),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle(this.icon, this.label, this.on, this.onTap);
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Icon(icon, size: 28, color: on ? FsColors.navy : FsColors.disabled),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: fsLabel),
          ],
        ),
      ),
    );
  }
}

/// Ergebnis der Runde. Liegt im unteren Bildschirmdrittel, damit der fertige
/// Turm darüber sichtbar bleibt.
class ResultsCard extends StatelessWidget {
  const ResultsCard({
    super.key,
    required this.result,
    required this.game,
    required this.onRestart,
    required this.onHome,
  });
  final RoundResult result;
  final FlipstackGame game;
  final VoidCallback onRestart, onHome;

  static String _time(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = result;
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: FsCard(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summit ? 'GIPFEL ERREICHT' : 'KEIN PLATZ MEHR',
                      style: fsLabel.copyWith(fontSize: 12.5, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.score}',
                      style: const TextStyle(
                        fontSize: 58,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: FsColors.navy,
                      ),
                    ),
                    Text(
                      r.newBest
                          ? 'Neuer Bestwert'
                          : 'Bestwert ${r.stats.bestScore}',
                      style: TextStyle(
                        color: r.newBest
                            ? FsColors.highlight
                            : FsColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (r.blockedPiece != null) ...[
                      const SizedBox(height: 12),
                      _BlockedInfo(r, game),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat('HÖHE', '${r.height}'),
                        _Stat('STEINE', '${r.pieces}'),
                        _Stat('COMBO', '${r.bestCombo}'),
                        _Stat('ZEIT', _time(r.seconds)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PillButton('NOCHMAL', onTap: onRestart, height: 60),
                    Pressable(
                      onTap: onHome,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        child: Text(
                          'HAUPTMENÜ',
                          style: fsLabel.copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
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
            color: FsColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: fsLabel),
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
      BlockCause.tooUneven =>
        'An jeder Stelle wäre der Turm mehr als ${r.maxSpread} Ebenen ungleich hoch geworden.',
      BlockCause.unsupported => 'An jeder Stelle hätte er zu wenig aufgelegen.',
      BlockCause.both =>
        'Er hätte zu wenig aufgelegen oder den Turm mehr als ${r.maxSpread} Ebenen ungleich hoch gemacht.',
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
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: FsColors.navy,
              ),
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
