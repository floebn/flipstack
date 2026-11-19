import 'package:flutter/material.dart';

import '../../game/core/player_stats.dart';
import '../../services/storage/settings_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Einstellungen und Statistik als Blatt von unten.
Future<void> showSettingsSheet(
  BuildContext context, {
  required Settings settings,
  required PlayerStats stats,
  required VoidCallback onTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FsColors.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EINSTELLUNGEN', style: fsLabel),
              _Toggle('Ton', settings.sound, (v) {
                settings.sound = v;
                onTap();
              }),
              _Toggle('Vibration', settings.haptics, (v) {
                settings.haptics = v;
                onTap();
              }),
              _Toggle(
                'Tutorial beim nächsten Start zeigen',
                !settings.tutorialDone,
                (v) {
                  settings.tutorialDone = !v;
                  onTap();
                },
              ),
              const SizedBox(height: 18),
              const Text('STATISTIK', style: fsLabel),
              const SizedBox(height: 8),
              _Row('Bestwert', '${stats.bestScore}'),
              _Row('Größte Höhe', '${stats.bestHeight}'),
              _Row('Beste Combo', '${stats.bestCombo}'),
              _Row('Gespielte Runden', '${stats.rounds}'),
              _Row('Durchschnitt', '${stats.averageScore} Punkte'),
              _Row('Abgelegte Bausteine', '${stats.totalPieces}'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: FsColors.navy,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: FsColors.action,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: FsColors.navy),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FsColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
