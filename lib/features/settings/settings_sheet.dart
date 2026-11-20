import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  VoidCallback? onPrivacyOptions,
  VoidCallback? onRemoveAds,
  bool adsRemoved = false,
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
              const SizedBox(height: 18),
              if (onRemoveAds != null) ...[
                const Text('WERBUNG', style: fsLabel),
                _Link(
                  adsRemoved ? 'Werbefrei · gekauft' : 'Werbefrei',
                  onRemoveAds,
                ),
                const SizedBox(height: 14),
              ],
              const Text('RECHTLICHES', style: fsLabel),
              if (onPrivacyOptions != null)
                _Link('Datenschutz-Einstellungen', () {
                  onTap();
                  Navigator.of(context).pop();
                  onPrivacyOptions();
                }),
              _Link(
                'Datenschutzerklärung',
                () => _open('flipstack/datenschutz/'),
              ),
              _Link('Support', () => _open('flipstack/support/')),
              _Link('Impressum', () => _open('impressum/')),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Öffnet eine Seite der Website im Browser. Schlägt das fehl (kein Browser,
/// kein Netz), passiert nichts.
Future<void> _open(String path) async {
  try {
    await launchUrl(
      Uri.parse('https://bosselgo.de/$path'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
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
              const Icon(
                Icons.chevron_right_rounded,
                color: FsColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
