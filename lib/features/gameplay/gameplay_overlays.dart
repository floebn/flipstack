import '../../l10n/tr.dart';

import 'package:flutter/material.dart';

import '../../game/meta/rewards.dart';
import '../rewards/rewards_ui.dart';
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
          Positioned(
            right: 26,
            top: 62,
            child: Text(
              t('NÄCHSTER', 'NEXT'),
              style: fsLabel.copyWith(color: FsColors.onBackgroundMuted),
            ),
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
                    color: FsColors.onBackground,
                    iconColor: FsColors.onBackgroundInverse,
                    semanticLabel: t(
                      'Plattform nach links drehen',
                      'Rotate platform left',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: PulseRing(
                    active: tutorial == TutorialStep.drop,
                    child: PillButton(
                      t('ABLEGEN', 'DROP'),
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
                    color: FsColors.onBackground,
                    iconColor: FsColors.onBackgroundInverse,
                    semanticLabel: t(
                      'Plattform nach rechts drehen',
                      'Rotate platform right',
                    ),
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
          style: TextStyle(
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w800,
            color: FsColors.onBackground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'HÖHE ${h.height}   ·   BESTWERT ${h.best}',
            'HEIGHT ${h.height}   ·   BEST ${h.best}',
          ),
          style: fsLabel.copyWith(color: FsColors.onBackgroundMuted),
        ),
        const SizedBox(height: 8),
        // Combo: zeigt den Multiplikator der nächsten sauberen Ablage
        AnimatedOpacity(
          opacity: h.combo >= 1 ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: FsChip(
            'COMBO ${h.combo}   ×${formatDecimal(h.multiplier)}',
            color: fsDarkBackground.value
                ? const Color(0xFF34435A)
                : FsColors.navy,
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

  static Map<TutorialStep, (String, String)> get _texts => {
    TutorialStep.move: (
      t('Verschieben', 'Move'),
      t(
        'Ziehe mit einem Finger, um den Stein zu bewegen.',
        'Drag with one finger to move the piece.',
      ),
    ),
    TutorialStep.drop: (
      t('Ablegen', 'Drop'),
      t(
        'Tippe auf ABLEGEN – oder einfach irgendwo auf den Bildschirm.',
        'Tap DROP – or simply anywhere on the screen.',
      ),
    ),
    TutorialStep.rotate: (
      t('Drehen', 'Rotate'),
      t(
        'Drehe die Plattform. Der Stein dreht sich nie mit – so änderst du, wie er liegt.',
        'Rotate the platform. The piece never turns with it – that is how you change the way it lands.',
      ),
    ),
    TutorialStep.rules: (
      t('Punkte', 'Points'),
      t(
        'Volle Auflage gibt Bonus und Combo. Bau gleichmäßig – ein Rahmen zeigt die erlaubte Höhe.',
        'Full support gives a bonus and builds your combo. Build evenly – a frame shows the allowed height.',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final texts = _texts[step];
    if (texts == null) return const SizedBox.shrink();
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
                        '${index + 1} / 4   ${texts.$1.toUpperCase()}',
                        style: fsLabel,
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: onSkip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Text(
                            t('ÜBERSPRINGEN', 'SKIP'),
                            style: fsLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    texts.$2,
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
                    PillButton(t('WEITER', 'RESUME'), onTap: onResume),
                    const SizedBox(height: 10),
                    PillButton(
                      t('NEU STARTEN', 'RESTART'),
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
                          t('Ton', 'Sound'),
                          settings.sound,
                          () => settings.sound = !settings.sound,
                        ),
                        _IconToggle(
                          Icons.vibration_rounded,
                          'Vibration',
                          settings.haptics,
                          () => settings.haptics = !settings.haptics,
                        ),
                        _IconToggle(
                          Icons.home_rounded,
                          t('Menü', 'Menu'),
                          true,
                          onHome,
                        ),
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

/// Ergebnis der Runde als Karte am unteren Rand; der fertige Turm bleibt
/// darüber sichtbar. Reihenfolge von oben: Punkte, Kennzahlen, Grund des
/// Spielendes, Angebote gegen freiwillige Werbung, Belohnungen, Aktionen.
class ResultsCard extends StatelessWidget {
  const ResultsCard({
    super.key,
    required this.result,
    required this.profile,
    required this.game,
    required this.onRestart,
    required this.onHome,
    this.onRevive,
    this.onDoubleCoins,
    this.coinsDoubled = false,
    this.onRemoveAds,
  });

  /// Öffnet den Kauf "Werbefrei"; `null` = nicht anbieten.
  final VoidCallback? onRemoveAds;

  /// Angebote gegen freiwillige Werbung; `null` = nicht verfügbar.
  final VoidCallback? onRevive, onDoubleCoins;
  final bool coinsDoubled;
  final RoundResult result;
  final Profile profile;
  final FlipstackGame game;
  final VoidCallback onRestart, onHome;

  static String _time(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = result;
    final bonus = r.rewards.roundCoins + r.rewards.stageCoins;
    final hasOffers = onRevive != null || onDoubleCoins != null || coinsDoubled;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 48 * (1 - t)),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.76,
                ),
                child: FsCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ScoreHeader(r),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _Tile(t('HÖHE', 'HEIGHT'), '${r.height}'),
                                    const SizedBox(width: 8),
                                    _Tile(t('STEINE', 'PIECES'), '${r.pieces}'),
                                    const SizedBox(width: 8),
                                    _Tile('COMBO', '${r.bestCombo}'),
                                    const SizedBox(width: 8),
                                    _Tile(t('ZEIT', 'TIME'), _time(r.seconds)),
                                  ],
                                ),
                                if (r.blockedPiece != null) ...[
                                  const SizedBox(height: 10),
                                  _BlockedInfo(r, game),
                                ],
                                if (hasOffers) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      if (onRevive != null)
                                        Expanded(
                                          child: PulseRing(
                                            active: true,
                                            radius: 22,
                                            child: _AdOffer(
                                              icon: Icons.replay_rounded,
                                              title: t(
                                                'Weiterspielen',
                                                'Continue',
                                              ),
                                              subtitle: t(
                                                'Stein tauschen',
                                                'Swap the piece',
                                              ),
                                              primary: true,
                                              onTap: onRevive!,
                                            ),
                                          ),
                                        ),
                                      if (onRevive != null &&
                                          (onDoubleCoins != null ||
                                              coinsDoubled))
                                        const SizedBox(width: 12),
                                      if (coinsDoubled)
                                        Expanded(
                                          child: _AdOffer(
                                            title: t(
                                              '+$bonus Münzen',
                                              '+$bonus coins',
                                            ),
                                            subtitle: t(
                                              'gutgeschrieben',
                                              'added',
                                            ),
                                          ),
                                        )
                                      else if (onDoubleCoins != null)
                                        Expanded(
                                          child: _AdOffer(
                                            title: t(
                                              '+$bonus Münzen',
                                              '+$bonus coins',
                                            ),
                                            subtitle: t(
                                              'Münzen verdoppeln',
                                              'Double your coins',
                                            ),
                                            onTap: onDoubleCoins!,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                RewardsSummary(
                                  rewards: r.rewards,
                                  profile: profile,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  RoundIconButton(
                                    Icons.home_rounded,
                                    onTap: onHome,
                                    size: 58,
                                    color: const Color(0xFFE4DFD4),
                                    iconColor: FsColors.navy,
                                    semanticLabel: t('Hauptmenü', 'Main menu'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: PillButton(
                                      t('NOCHMAL', 'PLAY AGAIN'),
                                      onTap: onRestart,
                                      height: 58,
                                    ),
                                  ),
                                ],
                              ),
                              if (onRemoveAds != null)
                                Pressable(
                                  onTap: onRemoveAds!,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      t('WERBUNG ENTFERNEN', 'REMOVE ADS'),
                                      style: fsLabel.copyWith(fontSize: 11.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Punkte der Runde: Etikett, grosse hochzählende Zahl, Bezug zum Bestwert.
class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader(this.r);
  final RoundResult r;

  @override
  Widget build(BuildContext context) {
    final best = r.newBest;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: best ? FsColors.highlight : const Color(0x14202B38),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (best) ...[
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                best
                    ? t('NEUER BESTWERT', 'NEW HIGH SCORE')
                    : r.reason == GameOverReason.summit
                    ? t('GIPFEL ERREICHT', 'SUMMIT REACHED')
                    : t('RUNDE BEENDET', 'ROUND OVER'),
                style: fsLabel.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.8,
                  color: best ? Colors.white : FsColors.navy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: r.score),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            '$v',
            style: const TextStyle(
              fontSize: 54,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: FsColors.navy,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          best
              ? t('Punkte', 'Points')
              : t(
                  'Punkte  ·  Bestwert ${r.stats.bestScore}',
                  'Points  ·  Best ${r.stats.bestScore}',
                ),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: FsColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Kennzahl der Runde als kleine Kachel.
class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: FsColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(label, style: fsLabel.copyWith(fontSize: 9.5)),
          ],
        ),
      ),
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
      BlockCause.tooUneven => t(
        'Überall wäre der Turm mehr als ${r.maxSpread} Ebenen ungleich hoch geworden.',
        'Everywhere the tower would have become more than ${r.maxSpread} levels uneven.',
      ),
      BlockCause.unsupported => t(
        'Überall hätte er zu wenig aufgelegen.',
        'Everywhere it would have had too little support.',
      ),
      BlockCause.both => t(
        'Zu wenig Auflage oder mehr als ${r.maxSpread} Ebenen Höhenunterschied.',
        'Too little support or more than ${r.maxSpread} levels of height difference.',
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0x0F202B38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 46,
            child: CustomPaint(painter: _PiecePainter(game, r.blockedPiece!)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: t(
                      'Dieser Stein passte nirgends. ',
                      'This piece did not fit anywhere. ',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: why),
                ],
              ),
              style: const TextStyle(
                fontSize: 12.5,
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

/// Angebot gegen freiwillige Werbung, bewusst auffällig: kräftige Fläche,
/// grosses Symbol und ein Schild "WERBUNG", damit vor dem Antippen klar ist,
/// dass eine Anzeige folgt und was es dafür gibt.
class _AdOffer extends StatelessWidget {
  const _AdOffer({
    required this.title,
    required this.subtitle,
    this.icon,
    this.primary = false,
    this.onTap,
  });
  final String title, subtitle;

  /// Symbol links; ohne Angabe die Münze.
  final IconData? icon;

  /// Wichtigstes Angebot: Bernstein statt Navy.
  final bool primary;

  /// `null` = bereits eingelöst.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = onTap == null;
    final fg = done || primary ? FsColors.navy : Colors.white;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: done
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: primary
                    ? const [Color(0xFFF7CE74), FsColors.reward]
                    : const [Color(0xFF2E3D50), FsColors.navy],
              ),
        color: done ? const Color(0x0F202B38) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: done
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x33202B38),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  color: FsColors.action,
                  size: 30,
                )
              else if (icon != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: FsColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: FsColors.reward, size: 22),
                )
              else
                const CoinIcon(size: 34),
              const Spacer(),
              if (!done)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary
                        ? const Color(0x33202B38)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 14, color: fg),
                      const SizedBox(width: 2),
                      Text(
                        t('WERBUNG', 'AD'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: done ? 0.6 : 0.8),
            ),
          ),
        ],
      ),
    );
    if (done) return card;
    return Semantics(
      button: true,
      label: t(
        '$title. $subtitle. Werbung ansehen',
        '$title. $subtitle. Watch an ad',
      ),
      child: Pressable(onTap: onTap!, child: card),
    );
  }
}
