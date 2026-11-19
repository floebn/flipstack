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
  });
  final PlayerStats stats;
  final Profile profile;
  final VoidCallback onPlay, onSettings, onQuests, onShop;

  /// Offene Tages- und Wochenaufgaben.
  String get _dailyDone =>
      '${profile.daily.where((q) => q.done).length}/${profile.daily.length}';

  /// Es gibt ein Stück, das mit dem Kontostand bezahlbar ist.
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
              semanticLabel: 'Einstellungen',
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'FLIP',
                        style: TextStyle(color: FsColors.navy),
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
                  'DREHEN  ·  STAPELN  ·  HOCH HINAUS',
                  style: fsLabel.copyWith(fontSize: 11.5),
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
                if (stats.rounds > 0) ...[
                  Text(
                    'BESTWERT ${stats.bestScore}   ·   HÖHE ${stats.bestHeight}',
                    style: fsLabel.copyWith(
                      fontSize: 12.5,
                      color: FsColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                PillButton('SPIELEN', onTap: onPlay, height: 70),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Secondary(
                        Icons.flag_rounded,
                        'AUFGABEN',
                        badge: profile.daily.isEmpty ? null : _dailyDone,
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

/// Nebenaktion im Hauptmenü (Aufgaben, Shop).
class _Secondary extends StatelessWidget {
  const _Secondary(
    this.icon,
    this.label, {
    required this.onTap,
    this.badge,
    this.dot = false,
  });

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
          height: 52,
          decoration: BoxDecoration(
            color: FsColors.cream,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22202B38),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FsColors.navy,
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
          ),
        ),
      ),
    );
  }
}
