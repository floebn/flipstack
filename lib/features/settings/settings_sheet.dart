import '../../l10n/tr.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../game/core/player_stats.dart';
import '../../services/storage/settings_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Einstellungen als Blatt von unten, in klar getrennten Karten:
/// Werbefrei (hervorgehoben), Spiel, Statistik, Rechtliches.
Future<void> showSettingsSheet(
  BuildContext context, {
  required Settings settings,
  required PlayerStats stats,
  required VoidCallback onTap,
  VoidCallback? onPrivacyOptions,
  VoidCallback? onRemoveAds,
  bool adsRemoved = false,
  String? removeAdsPrice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FsColors.cream,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // unter Statusleiste und Dynamic Island bleiben
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.viewPaddingOf(context).top -
                72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                child: Text(
                  t('Einstellungen', 'Settings'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: FsColors.navy,
                  ),
                ),
              ),
              if (onRemoveAds != null) ...[
                _Premium(
                  owned: adsRemoved,
                  price: removeAdsPrice,
                  onTap: onRemoveAds,
                ),
                const SizedBox(height: 14),
              ],
              _Group(t('SPIEL', 'GAME'), [
                _Toggle(
                  Icons.volume_up_rounded,
                  t('Ton', 'Sound'),
                  settings.sound,
                  (v) {
                    settings.sound = v;
                    onTap();
                  },
                ),
                _Toggle(
                  Icons.vibration_rounded,
                  'Vibration',
                  settings.haptics,
                  (v) {
                    settings.haptics = v;
                    onTap();
                  },
                ),
                _Toggle(
                  Icons.school_rounded,
                  t('Tutorial beim nächsten Start', 'Show tutorial next time'),
                  !settings.tutorialDone,
                  (v) {
                    settings.tutorialDone = !v;
                    onTap();
                  },
                ),
              ]),
              const SizedBox(height: 14),
              _StatsCard(stats),
              const SizedBox(height: 14),
              _Group(t('RECHTLICHES', 'LEGAL'), [
                if (onPrivacyOptions != null)
                  _Link(
                    Icons.tune_rounded,
                    t('Datenschutz-Einstellungen', 'Privacy settings'),
                    () {
                      onTap();
                      Navigator.of(context).pop();
                      onPrivacyOptions();
                    },
                  ),
                _Link(
                  Icons.shield_outlined,
                  t('Datenschutzerklärung', 'Privacy policy'),
                  () => _open(
                    t('flipstack/datenschutz/', 'flipstack/en/privacy/'),
                  ),
                ),
                _Link(
                  Icons.mail_outline_rounded,
                  'Support',
                  () => _open(t('flipstack/support/', 'flipstack/en/support/')),
                ),
                _Link(
                  Icons.info_outline_rounded,
                  t('Impressum', 'Legal notice'),
                  () => _open(t('impressum/', 'impressum/en/')),
                ),
              ]),
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

const _rowText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: FsColors.navy,
);

/// Hervorgehobene Karte für den Kauf "Werbefrei".
class _Premium extends StatelessWidget {
  const _Premium({
    required this.owned,
    required this.price,
    required this.onTap,
  });
  final bool owned;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: owned
          ? t('Werbefrei, gekauft', 'Ad-free, purchased')
          : t('Werbefrei kaufen', 'Buy ad-free'),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B3A4C), FsColors.navy],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33202B38),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: FsColors.reward,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  owned ? Icons.check_rounded : Icons.block_rounded,
                  color: FsColors.navy,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Werbefrei', 'Ad-Free'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owned
                          ? t(
                              'Aktiv. Danke für deine Unterstützung',
                              'Active. Thank you for your support',
                            )
                          : t(
                              'Keine Werbung zwischen den Runden',
                              'No ads between rounds',
                            ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!owned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: FsColors.action,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    price ?? t('Ansehen', 'View'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karte mit Überschrift und durch feine Linien getrennten Zeilen.
class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(title, style: fsLabel),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 54,
                    color: Color(0x14202B38),
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0x14202B38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: FsColors.navy),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              _RowIcon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: _rowText)),
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
  const _Toggle(this.icon, this.label, this.value, this.onChanged);
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
      child: Row(
        children: [
          _RowIcon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: _rowText)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: FsColors.action,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Statistik als Kacheln: Bestwert gross, die übrigen Werte im Raster.
class _StatsCard extends StatelessWidget {
  const _StatsCard(this.stats);
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FsColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: fsLabel.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(t('STATISTIK', 'STATS'), style: fsLabel),
        ),
        Row(
          children: [
            tile(t('BESTWERT', 'BEST'), '${stats.bestScore}'),
            const SizedBox(width: 8),
            tile(t('HÖHE', 'HEIGHT'), '${stats.bestHeight}'),
            const SizedBox(width: 8),
            tile('COMBO', '${stats.bestCombo}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(t('RUNDEN', 'ROUNDS'), '${stats.rounds}'),
            const SizedBox(width: 8),
            tile(t('SCHNITT', 'AVERAGE'), '${stats.averageScore}'),
            const SizedBox(width: 8),
            tile(t('STEINE', 'PIECES'), '${stats.totalPieces}'),
          ],
        ),
      ],
    );
  }
}
