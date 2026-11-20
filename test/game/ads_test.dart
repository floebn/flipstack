import 'dart:math' as math;

import 'package:flipstack/game/core/game_session.dart';
import 'package:flipstack/game/meta/ad_policy.dart';
import 'package:flipstack/game/meta/rewards.dart';
import 'package:flipstack/services/ads/ads_service.dart';
import 'package:flipstack/services/purchases/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vollbildwerbung zwischen Runden', () {
    // Lange Runden, App schon lange offen: nur die Rundenzählung entscheidet.
    bool round(
      AdPolicy p,
      double now, {
      int seconds = 120,
      bool rewarded = false,
    }) => p.roundFinished(
      now: now,
      roundSeconds: seconds,
      rewardedThisRound: rewarded,
    );

    test('erste nach drei Runden, danach höchstens jede vierte', () {
      final p = AdPolicy();
      final shown = <int>[];
      var now = 200.0;
      for (var i = 1; i <= 12; i++) {
        now += 240;
        if (round(p, now)) {
          shown.add(i);
          p.interstitialShown(now);
        }
      }
      expect(shown, [3, 7, 11]);
    });

    test('nicht kurz nach dem Öffnen der App', () {
      final p = AdPolicy();
      expect(round(p, 20), isFalse);
      expect(round(p, 50), isFalse);
      expect(
        round(p, 80),
        isFalse,
        reason: 'dritte Runde, aber erst 80 s offen',
      );
      expect(round(p, 300), isTrue);
    });

    test('Mindestabstand in Sekunden gilt zusätzlich zur Rundenzahl', () {
      final p = AdPolicy();
      for (var i = 0; i < 3; i++) {
        round(p, 300);
      }
      p.interstitialShown(300);
      for (var i = 0; i < 3; i++) {
        expect(round(p, 330), isFalse);
      }
      expect(
        round(p, 400),
        isFalse,
        reason: 'vierte Runde, aber erst 100 s her',
      );
      expect(round(p, 500), isTrue);
    });

    test('nicht nach kurzer Runde, Tutorial, belohnter Werbung oder Kauf', () {
      AdPolicy ready() {
        final p = AdPolicy();
        round(p, 300);
        round(p, 300);
        return p;
      }

      expect(round(ready(), 300, seconds: 39), isFalse);
      expect(round(ready(), 300, rewarded: true), isFalse);
      expect(
        ready().roundFinished(now: 300, roundSeconds: 120, tutorial: true),
        isFalse,
      );
      expect(
        ready().roundFinished(now: 300, roundSeconds: 120, adsRemoved: true),
        isFalse,
      );
      expect(round(ready(), 300), isTrue);
    });

    test('eine fortgesetzte Runde zählt nur einmal', () {
      final p = AdPolicy();
      round(p, 300);
      round(p, 300);
      p.roundResumed();
      expect(p.rounds, 1);
      expect(round(p, 300, rewarded: true), isFalse);
      expect(round(p, 300), isTrue);
    });

    test('ohne Werbe-SDK gibt es keine Angebote und keine Werbung', () async {
      final ads = NoAds();
      expect(ads.rewardedReady, isFalse);
      expect(await ads.showRewarded(RewardedPlacement.revive), isFalse);
      expect(await ads.showInterstitial(), isFalse);
    });
  });

  group('Zweite Chance', () {
    GameSession blocked(int seed) {
      final s = GameSession(seed: seed);
      final rng = math.Random(seed);
      while (s.phase != GamePhase.gameOver) {
        final o = s.rules.validPlacements(s.board, s.current);
        final (x, y, r) = o[rng.nextInt(o.length)];
        s.orientation = r;
        s.moveTo(x, y);
        s.place();
        s.finishPlacing();
      }
      return s;
    }

    test('tauscht den Stein, lässt Turm und Punkte, geht nur einmal', () {
      for (var seed = 1; seed <= 20; seed++) {
        final s = blocked(seed);
        final score = s.score, cells = s.board.cells.length;
        expect(s.canRevive, isTrue);
        expect(s.revive(), isTrue);
        expect(s.phase, GamePhase.preview);
        expect((s.score, s.board.cells.length), (score, cells));
        expect(s.rules.hasAnyValidPlacement(s.board, s.current), isTrue);
        expect(s.gameOverReason, isNull);
        // Runde bis zum nächsten Ende spielen: kein zweites Mal
        final rng = math.Random(seed);
        while (s.phase != GamePhase.gameOver) {
          final o = s.rules.validPlacements(s.board, s.current);
          final (x, y, r) = o[rng.nextInt(o.length)];
          s.orientation = r;
          s.moveTo(x, y);
          s.place();
          s.finishPlacing();
        }
        expect(s.canRevive, isFalse);
        expect(s.revive(), isFalse);
      }
    });

    test('nicht während der laufenden Runde', () {
      final s = GameSession(seed: 1);
      expect(s.canRevive, isFalse);
      expect(s.revive(), isFalse);
    });
  });

  group('Kauf Werbefrei', () {
    test('ohne Store gibt es kein Angebot', () async {
      final p = NoPurchases();
      await p.load();
      expect((p.adsRemoved, p.price, p.busy), (false, null, false));
      await p.buyRemoveAds();
      expect(p.adsRemoved, isFalse);
    });

    test(
      'Kauf schaltet frei und meldet es; Wiederherstellen ohne Kauf nicht',
      () async {
        final p = FakePurchases();
        var changes = 0;
        p.addListener(() => changes++);
        await p.restore();
        expect(
          (p.adsRemoved, p.notice),
          (false, PurchaseNotice.nothingToRestore),
        );
        p.clearNotice();
        await p.buyRemoveAds();
        expect(
          (p.adsRemoved, p.notice, p.busy),
          (true, PurchaseNotice.bought, false),
        );
        expect(changes, greaterThanOrEqualTo(4));
        await p.restore();
        expect(p.notice, PurchaseNotice.restored);
      },
    );

    test('nach dem Kauf kommt keine Vollbildwerbung mehr', () {
      final policy = AdPolicy();
      for (var i = 0; i < 12; i++) {
        expect(
          policy.roundFinished(
            now: 300.0 + i * 300,
            roundSeconds: 120,
            adsRemoved: true,
          ),
          isFalse,
        );
      }
    });
  });

  test('Bonusmünzen erhöhen Kontostand und Zähler', () {
    final p = const Profile(coins: 100).withBonus(62);
    expect(p.coins, 162);
    expect(p.counter(Counter.coinsEarned), 62);
    expect(identical(p.withBonus(0), p), isTrue);
  });
}
