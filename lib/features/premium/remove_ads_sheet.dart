import 'package:flutter/material.dart';

import '../../services/purchases/purchase_service.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Blatt für den einmaligen Kauf "Werbefrei". Sagt vor dem Kauf genau, was
/// er bewirkt, zeigt den Preis aus dem Store und bietet das Wiederherstellen.
Future<void> showRemoveAdsSheet(
  BuildContext context,
  PurchaseService purchases, {
  required VoidCallback onTap,
}) {
  purchases.clearNotice();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FsColors.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => ListenableBuilder(
      listenable: purchases,
      builder: (context, _) {
        final owned = purchases.adsRemoved;
        final price = purchases.price;
        final note = switch (purchases.notice) {
          PurchaseNotice.bought =>
            'Danke! Die Werbung zwischen den Runden ist aus.',
          PurchaseNotice.restored => 'Kauf wiederhergestellt.',
          PurchaseNotice.nothingToRestore =>
            'Für dieses Konto wurde kein Kauf gefunden.',
          PurchaseNotice.pending =>
            'Der Kauf wartet auf eine Bestätigung. Er wird freigeschaltet, '
                'sobald sie vorliegt.',
          PurchaseNotice.failed =>
            'Das hat nicht geklappt. Es wurde nichts berechnet. '
                'Bitte versuch es später noch einmal.',
          PurchaseNotice.none => null,
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WERBEFREI', style: fsLabel),
                const SizedBox(height: 8),
                Text(
                  owned ? 'Du spielst werbefrei' : 'Spielen ohne Unterbrechung',
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: FsColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                const _Point(
                  Icons.block_rounded,
                  'Keine Werbung mehr zwischen den Runden',
                ),
                const _Point(
                  Icons.smart_display_rounded,
                  'Freiwillige Werbung für Belohnungen bleibt als Angebot',
                ),
                const _Point(
                  Icons.all_inclusive_rounded,
                  'Einmal kaufen, bleibt für immer. Kein Abo',
                ),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x14202B38),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: FsColors.navy,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (!owned)
                  IgnorePointer(
                    ignoring: price == null || purchases.busy,
                    child: PillButton(
                      purchases.busy
                          ? 'EINEN MOMENT …'
                          : price == null
                          ? 'DERZEIT NICHT VERFÜGBAR'
                          : 'KAUFEN  ·  $price',
                      enabled: price != null && !purchases.busy,
                      height: 58,
                      onTap: () {
                        onTap();
                        purchases.buyRemoveAds();
                      },
                    ),
                  ),
                if (!owned)
                  Center(
                    child: Pressable(
                      onTap: () {
                        if (purchases.busy) return;
                        onTap();
                        purchases.restore();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        child: Text(
                          'KÄUFE WIEDERHERSTELLEN',
                          style: fsLabel.copyWith(
                            fontSize: 12,
                            color: FsColors.navy,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 21, color: const Color(0xFF1F8A7B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: FsColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
