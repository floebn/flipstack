import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/theme/fs_colors.dart';

/// Wofür der Spieler freiwillig eine Werbung ansieht.
enum RewardedPlacement { revive, doubleCoins, shopCoins }

/// Werbung hinter einer Schnittstelle. Meldet Zuhörern, wenn sich
/// [rewardedReady] ändert, damit die Oberfläche Angebote ein- und ausblendet.
/// Das Spiel kennt kein Werbe-SDK; ohne
/// Einwilligung oder ohne Netz gilt einfach [NoAds].
abstract class AdsService extends ChangeNotifier {
  /// Es kann gerade eine belohnte Werbung gezeigt werden. Nur dann bietet die
  /// Oberfläche eine Belohnung an.
  bool get rewardedReady;

  /// Zeigt eine belohnte Werbung. `true` nur, wenn sie zu Ende gesehen wurde
  /// und die Belohnung gewährt werden darf.
  Future<bool> showRewarded(RewardedPlacement placement);

  /// Zeigt eine Vollbildwerbung zwischen zwei Runden. `true`, wenn wirklich
  /// eine gezeigt wurde.
  Future<bool> showInterstitial();
}

/// Keine Werbung: Standard, solange kein Werbe-SDK eingebunden ist, und der
/// Zustand bei verweigerter Einwilligung.
class NoAds extends AdsService {
  @override
  bool get rewardedReady => false;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async => false;

  @override
  Future<bool> showInterstitial() async => false;
}

/// Platzhalter zum Testen der Abläufe ohne Werbe-SDK
/// (`--dart-define=FS_ADS=fake`). Zeigt statt einer Anzeige eine Karte mit
/// Countdown; die belohnte Variante lässt sich abbrechen.
class FakeAds extends AdsService {
  FakeAds(this._context);
  final BuildContext Function() _context;

  @override
  bool get rewardedReady => true;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) =>
      _show('Belohnte Testwerbung', seconds: 3, canCancel: true);

  @override
  Future<bool> showInterstitial() =>
      _show('Testwerbung zwischen zwei Runden', seconds: 2, canCancel: false);

  Future<bool> _show(
    String title, {
    required int seconds,
    required bool canCancel,
  }) async {
    final done = await showDialog<bool>(
      context: _context(),
      barrierDismissible: false,
      barrierColor: const Color(0xE6202B38),
      builder: (context) => _FakeAd(title, seconds, canCancel),
    );
    return done ?? false;
  }
}

class _FakeAd extends StatefulWidget {
  const _FakeAd(this.title, this.seconds, this.canCancel);
  final String title;
  final int seconds;
  final bool canCancel;

  @override
  State<_FakeAd> createState() => _FakeAdState();
}

class _FakeAdState extends State<_FakeAd> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FsColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: FsColors.navy,
        ),
      ),
      content: Text(
        'Hier erscheint später die Anzeige.\nEndet in $_left s.',
        style: const TextStyle(fontSize: 15, color: FsColors.navy),
      ),
      actions: [
        if (widget.canCancel)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Abbrechen (keine Belohnung)',
              style: TextStyle(color: FsColors.textMuted),
            ),
          ),
      ],
    );
  }
}
