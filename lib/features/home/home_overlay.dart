import 'package:flutter/material.dart';

import '../../game/core/player_stats.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Hauptmenü. Liegt über dem Spiel, das dahinter einen Beispielturm zeigt.
class HomeOverlay extends StatelessWidget {
  const HomeOverlay({
    super.key,
    required this.stats,
    required this.onPlay,
    required this.onSettings,
  });
  final PlayerStats stats;
  final VoidCallback onPlay, onSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
