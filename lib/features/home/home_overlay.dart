import '../../l10n/tr.dart';

import 'package:flutter/material.dart';

import '../../game/core/player_stats.dart';
import '../../game/meta/rewards.dart';
import '../rewards/rewards_ui.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Hauptmenü. Liegt über dem Spiel, das dahinter einen Beispielturm zeigt.
class HomeOverlay extends StatelessWidget {
  const HomeOverlay({
    super.key,
    required this.stats,
    required this.profile,
    required this.onPlay,
    required this.onSettings,
    required this.onQuests,
    required this.onShop,
    this.savedRound,
    this.onContinue,
  });

  /// Noch nicht beendete Runde, die fortgesetzt werden kann.
  final ({int height, int score})? savedRound;
  final VoidCallback? onContinue;
  final PlayerStats stats;
  final Profile profile;
  final VoidCallback onPlay, onSettings, onQuests, onShop;

  /// Offene Tages- und Wochenaufgaben.
  String get _dailyDone =>
      '${profile.daily.where((q) => q.done).length}/${profile.daily.length}';

  /// Es gibt ein Stück, das mit dem Kontostand bezahlbar ist.
  /// Fortschritt je Tagesaufgabe, 0 bis 1.
  List<double> get _dailyProgress => [
    for (final q in profile.daily)
      if (q.done)
        1.0
      else
        (q.progress / (Quests.byId[q.id]?.target ?? 1)).clamp(0.0, 1.0),
  ];

  bool get _dailyAllDone =>
      profile.daily.isNotEmpty && profile.daily.every((q) => q.done);

  bool get _canBuy =>
      Cosmetics.all.any((c) => !profile.owns(c.id) && profile.coins >= c.price);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(left: 18, top: 12, child: CoinBadge(profile.coins)),
          Positioned(
            right: 18,
            top: 8,
            child: RoundIconButton(
              Icons.tune_rounded,
              onTap: onSettings,
              size: 46,
              color: FsColors.cream,
              iconColor: FsColors.navy,
              semanticLabel: t('Einstellungen', 'Settings'),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'FLIP',
                        style: TextStyle(color: FsColors.onBackground),
                      ),

                      TextSpan(
                        text: 'STACK',
                        style: TextStyle(color: FsColors.mint),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 56,
                    height: 1,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    'DREHEN  ·  STAPELN  ·  HOCH HINAUS',
                    'ROTATE  ·  STACK  ·  AIM HIGH',
                  ),
                  style: fsLabel.copyWith(
                    fontSize: 11.5,
                    color: FsColors.onBackgroundMuted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 34,
            child: Column(
              children: [
                if (stats.rounds > 0 && savedRound == null) ...[
                  _BestCard(score: stats.bestScore, height: stats.bestHeight),
                  const SizedBox(height: 12),
                ],
                if (savedRound != null && onContinue != null) ...[
                  PillButton(
                    t('RUNDE FORTSETZEN', 'CONTINUE ROUND'),
                    onTap: onContinue!,
                    height: 70,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Höhe ${savedRound!.height}  ·  ${savedRound!.score} Punkte',
                      'Height ${savedRound!.height}  ·  ${savedRound!.score} points',
                    ),
                    style: fsLabel.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      color: FsColors.onBackgroundMuted,
                    ),
                  ),
                  Pressable(
                    onTap: onPlay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      child: Text(
                        t('NEUE RUNDE', 'NEW ROUND'),
                        style: fsLabel.copyWith(
                          fontSize: 12.5,
                          color: FsColors.onBackground,
                        ),
                      ),
                    ),
                  ),
                ] else
                  PillButton(t('SPIELEN', 'PLAY'), onTap: onPlay, height: 70),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Secondary(
                        Icons.flag_rounded,
                        t('AUFGABEN', 'QUESTS'),
                        badge: profile.daily.isEmpty ? null : _dailyDone,
                        segments: profile.daily.isEmpty ? null : _dailyProgress,
                        complete: _dailyAllDone,
                        onTap: onQuests,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Secondary(
                        Icons.palette_rounded,
                        'SHOP',
                        dot: _canBuy,
                        onTap: onShop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bestwert und größte Höhe auf einer eigenen Karte, damit sie vor jeder
/// Plattform und jedem Hintergrund lesbar bleiben.
class _BestCard extends StatelessWidget {
  const _BestCard({required this.score, required this.height});

  final int score, height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: t(
        'Bestwert $score, größte Höhe $height',
        'Best score $score, best height $height',
      ),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: FsColors.cream,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14202B38),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stat(
              Icons.emoji_events_rounded,
              FsColors.highlight,
              t('BESTWERT', 'BEST'),
              formatInt(score),
            ),
            Container(
              width: 1,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0x22202B38),
            ),
            _stat(
              Icons.layers_rounded,
              FsColors.mint,
              t('HÖHE', 'HEIGHT'),
              '$height',
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, Color tint, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 6),
        Text(
          label,
          style: fsLabel.copyWith(
            fontSize: 10,
            letterSpacing: 1.1,
            color: FsColors.navy.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: FsColors.navy,
          ),
        ),
      ],
    );
  }
}

/// Nebenaktion im Hauptmenü (Aufgaben, Shop).
class _Secondary extends StatelessWidget {
  const _Secondary(
    this.icon,
    this.label, {
    required this.onTap,
    this.badge,
    this.dot = false,
    this.segments,
    this.complete = false,
  });

  /// Fortschritt je Aufgabe (0 bis 1), als schmale Balken unter der Schrift.
  final List<double>? segments;

  /// Alles erledigt: Zähler und Balken in der Erfolgsfarbe.
  final bool complete;

  /// Kleiner Punkt: hier gibt es etwas Neues.
  final bool dot;
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: FsColors.cream,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22202B38),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _line(),
              if (segments != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, v) in segments!.indexed) ...[
                      if (i > 0) const SizedBox(width: 4),
                      _segment(v),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(double v) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.5),
      child: SizedBox(
        width: 30,
        height: 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x1F202B38)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: const ColoredBox(color: FsColors.mint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: FsColors.navy),
        const SizedBox(width: 8),
        Text(
          label,
          style: fsLabel.copyWith(fontSize: 12.5, color: FsColors.navy),
        ),
        if (dot) ...[
          const SizedBox(width: 8),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: FsColors.highlight,
              shape: BoxShape.circle,
            ),
          ),
        ],
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: complete ? FsColors.mint : FsColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
