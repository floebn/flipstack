import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flipstack/game/meta/rewards.dart';
import 'package:flipstack/game/render/looks.dart';
import 'package:flipstack/services/storage/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

RoundSummary round({
  int score = 0,
  int height = 0,
  int pieces = 1,
  int combo = 0,
  int rotations = 0,
  int clean = 0,
  int layers = 0,
}) => RoundSummary(
  score: score,
  height: height,
  pieces: pieces,
  bestCombo: combo,
  rotations: rotations,
  cleanPlacements: clean,
  layers: layers,
);

void main() {
  final thu = DateTime(2026, 11, 19, 21); // Donnerstag

  group('Aufgaben', () {
    test('Tages- und Wochenschlüssel', () {
      expect(Quests.dayKey(thu), '2026-11-19');
      expect(Quests.weekKey(thu), '2026-11-16');
      expect(Quests.weekKey(DateTime(2026, 11, 22, 23, 59)), '2026-11-16');
      expect(Quests.weekKey(DateTime(2026, 11, 23)), '2026-11-23');
    });

    test(
      'je Zeitraum drei verschiedene Arten, für denselben Tag dieselben',
      () {
        for (var d = 1; d <= 28; d++) {
          final key = Quests.dayKey(DateTime(2026, 2, d));
          final a = Quests.pick(Quests.dailyPool, key);
          expect(a.length, 3);
          expect({for (final q in a) q.kind}.length, 3);
          expect(
            [for (final q in Quests.pick(Quests.dailyPool, key)) q.id],
            [for (final q in a) q.id],
          );
          expect(Quests.pick(Quests.weeklyPool, key).length, 3);
        }
      },
    );

    test('neuer Tag bringt neue Tagesaufgaben, die Woche läuft weiter', () {
      final a = const Profile().refreshed(thu);
      final (b, _) = a.recordRound(round(score: 300, pieces: 10), thu);
      final c = b.refreshed(thu.add(const Duration(days: 1)));
      expect(c.day, '2026-11-20');
      expect(c.daily.every((q) => q.progress == 0 && !q.done), isTrue);
      expect(c.week, b.week);
      expect(
        [for (final q in c.weekly) q.progress],
        [for (final q in b.weekly) q.progress],
      );
      expect(
        identical(c.refreshed(thu.add(const Duration(days: 1))), c),
        isTrue,
      );
    });

    test('Summen wachsen über Runden, Bestwerte zählen je Runde', () {
      const sum = QuestDef('x', QuestKind.pieces, 30, 40);
      const best = QuestDef('y', QuestKind.height, 8, 40);
      const times = QuestDef('z', QuestKind.heightRounds, 3, 250, param: 20);
      expect(sum.isSum, isTrue);
      expect(best.isSum, isFalse);
      expect(sum.contribution(round(pieces: 12), 0), 12);
      expect(best.contribution(round(height: 7), 0), 7);
      expect(times.contribution(round(height: 19), 0), 0);
      expect(times.contribution(round(height: 20), 0), 1);
    });

    test('erfüllte Aufgabe wird genau einmal belohnt', () {
      var p = const Profile().refreshed(thu);
      var paid = 0;
      for (var i = 0; i < 6; i++) {
        final (next, r) = p.recordRound(
          round(
            score: 9000,
            height: 22,
            pieces: 80,
            combo: 9,
            rotations: 12,
            clean: 30,
            layers: 5,
          ),
          thu,
        );
        paid += r.quests.fold<int>(0, (s, q) => s + q.reward);
        p = next;
      }
      expect(p.daily.every((q) => q.done), isTrue);
      final daily = Quests.pick(Quests.dailyPool, p.day);
      final weeklyDone = [
        for (final q in p.weekly)
          if (q.done) Quests.byId[q.id]!,
      ];
      expect(
        paid,
        [...daily, ...weeklyDone].fold<int>(0, (s, q) => s + q.reward),
      );
    });
  });

  group('Münzen und Erfolge', () {
    test('Münzen: Punkte / 100, mindestens 1, plus 10 je Etappe', () {
      final p = const Profile().refreshed(thu);
      expect(p.recordRound(round(score: 40), thu).$2.roundCoins, 1);
      expect(p.recordRound(round(score: 0, pieces: 0), thu).$2.roundCoins, 0);
      final r = p.recordRound(round(score: 6250, height: 23), thu).$2;
      expect((r.roundCoins, r.stageCoins), (62, 20));
    });

    test('Kontostand wächst genau um die ausgewiesene Summe', () {
      var p = const Profile().refreshed(thu);
      var sum = 0;
      for (var i = 0; i < 8; i++) {
        final (next, r) = p.recordRound(
          round(score: 1500 * i, height: 4 * i, pieces: 20 * i, combo: i),
          thu,
        );
        sum += r.total;
        p = next;
      }
      expect(p.coins, sum);
      expect(p.counter(Counter.coinsEarned), sum);
      expect(p.counter(Counter.rounds), 8);
    });

    test('Erfolg wird einmal freigeschaltet', () {
      final (a, r1) = const Profile().recordRound(round(height: 11), thu);
      expect([
        for (final x in r1.achievements) x.id,
      ], containsAll(['first_stack', 'higher']));
      final (_, r2) = a.recordRound(round(height: 12), thu);
      expect(r2.achievements, isEmpty);
    });

    test('Kennungen sind eindeutig', () {
      for (final ids in [
        [for (final a in Achievements.all) a.id],
        [for (final c in Cosmetics.all) c.id],
        [
          for (final q in [...Quests.dailyPool, ...Quests.weeklyPool]) q.id,
        ],
      ]) {
        expect(ids.toSet().length, ids.length);
      }
    });
  });

  group('Freischaltungen', () {
    test('kaufen kostet Münzen und wählt aus; zu wenig Münzen geht nicht', () {
      const poor = Profile(coins: 249);
      expect(poor.buy('bg_dawn'), isNull);
      final p = const Profile(coins: 300).buy('bg_dawn')!;
      expect(p.coins, 50);
      expect(p.equippedIn(CosmeticCategory.background).id, 'bg_dawn');
      expect(p.buy('bg_dawn'), isNull, reason: 'schon vorhanden');
      expect(p.equip('bg_mist'), isNull, reason: 'nicht gekauft');
      expect(
        p.equip('bg_sand')!.equippedIn(CosmeticCategory.background).id,
        'bg_sand',
      );
    });

    test('jede Kategorie hat genau einen kostenlosen Standard', () {
      for (final c in CosmeticCategory.values) {
        expect(Cosmetics.of(c).where((x) => x.price == 0).length, 1);
        expect(const Profile().equippedIn(c).price, 0);
      }
    });

    test('nächste Freischaltung ist die günstigste fehlende', () {
      expect(const Profile().nextUnlock!.id, 'bg_dawn');
      expect(const Profile(owned: {'bg_dawn'}).nextUnlock!.id, 'fx_confetti');
    });

    test('jede Freischaltung hat ein Aussehen', () {
      for (final c in Cosmetics.of(CosmeticCategory.blocks)) {
        expect(Looks.palettes[c.id]?.length, 8, reason: c.id);
      }
      for (final c in Cosmetics.of(CosmeticCategory.material)) {
        final (cube, gloss) = Looks.materials[c.id]!;
        expect(File('assets/sprites/$cube').existsSync(), isTrue, reason: c.id);
        if (gloss != null) {
          expect(File('assets/sprites/$gloss').existsSync(), isTrue);
        }
        expect(
          File('assets/ui/mat_${c.id.substring(4)}.png').existsSync(),
          isTrue,
          reason: c.id,
        );
      }
      for (final c in Cosmetics.of(CosmeticCategory.background)) {
        expect(Looks.backgrounds.containsKey(c.id), isTrue, reason: c.id);
        final scene = Looks.backgrounds[c.id]!.scene;
        if (scene != null) {
          expect(File('assets/backgrounds/$scene').existsSync(), isTrue);
        }
      }
      for (final c in Cosmetics.of(CosmeticCategory.platform)) {
        expect(
          File(Looks.platformPreview(c.id)).existsSync(),
          isTrue,
          reason: c.id,
        );
        final set = Looks.platformSets[c.id];
        if (set != null) {
          expect(
            File('assets/sprites/platform_${set}_still.png').existsSync(),
            isTrue,
          );
          expect(
            File('assets/sprites/platform_${set}_029.png').existsSync(),
            isTrue,
          );
        }
      }
    });

    test('Farben einer Palette bleiben unterscheidbar', () {
      double dist(Color a, Color b) {
        final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255;
        final db = (a.b - b.b) * 255;
        return math.sqrt(dr * dr + dg * dg + db * db);
      }

      // Eigene Paletten halten 45 Abstand. Die vier vorgegebenen Paletten
      // bleiben je in einer Farbfamilie und liegen enger beieinander; für sie
      // gilt nur, dass keine zwei Farben fast gleich sind.
      const given = {
        'blocks_sunset',
        'blocks_lagoon',
        'blocks_lavender',
        'blocks_volcano',
      };
      Looks.palettes.forEach((id, colors) {
        expect(colors.length, 8, reason: id);
        for (var i = 0; i < colors.length; i++) {
          for (var j = i + 1; j < colors.length; j++) {
            expect(
              dist(colors[i], colors[j]),
              greaterThan(given.contains(id) ? 25 : 45),
              reason: '$id: Farbe $i und $j',
            );
          }
        }
      });
    });

    test('der Shop zeigt jede Kategorie vom günstigsten zum teuersten', () {
      for (final c in CosmeticCategory.values) {
        final prices = [for (final x in Cosmetics.of(c)) x.price];
        expect(prices, [...prices]..sort(), reason: c.name);
        expect(prices.first, 0);
      }
      expect(Cosmetics.of(CosmeticCategory.material).last.id, 'mat_stud');
    });
  });

  group('Speicherung', () {
    test('Stand übersteht Speichern und Laden', () {
      var p = const Profile(coins: 900).refreshed(thu);
      p = p.buy('blocks_arctic')!;
      p = p.recordRound(round(score: 4000, height: 12, pieces: 50), thu).$1;
      final q = Profile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(q.toJson()), jsonEncode(p.toJson()));
      expect(q.equippedIn(CosmeticCategory.blocks).id, 'blocks_arctic');
    });

    test('fehlerhafte oder unbekannte Einträge werden übergangen', () {
      final p = Profile.fromJson({
        'coins': -5,
        'owned': ['gibt_es_nicht', 'bg_dawn', 7],
        'equipped': {'background': 'blocks_arctic', 'blocks': 'unbekannt'},
        'daily': [
          {'id': 'entfernt', 'p': 3},
          {'id': 'd_rot10', 'p': 'x'},
        ],
        'counters': 'kaputt',
      });
      expect(p.coins, 0);
      expect(p.owned, {'bg_dawn'});
      expect(p.equippedIn(CosmeticCategory.background).id, 'bg_sand');
      expect(p.daily.single.id, 'd_rot10');
      expect(p.daily.single.progress, 0);
    });

    test('vor dem Laden überschreibt nichts den gespeicherten Stand', () async {
      final store = MemoryProfileStore(const Profile(coins: 400));
      final c = ProfileController(store, clock: () => thu);
      c.refresh(); // z. B. App kommt in den Vordergrund, bevor geladen ist
      expect((await store.load()).coins, 400);
      await c.load();
      expect(c.profile.coins, 400);
    });

    test('Controller speichert jede Änderung und erneuert Aufgaben', () async {
      var now = thu;
      final store = MemoryProfileStore(const Profile(coins: 400));
      final c = ProfileController(store, clock: () => now);
      await c.load();
      expect(c.profile.daily.length, 3);
      expect(c.buy('bg_dawn'), isTrue);
      expect((await store.load()).coins, 150);
      expect(c.buy('bg_dusk'), isFalse);
      final r = c.recordRound(round(score: 500));
      expect((await store.load()).coins, 150 + r.total);
      now = thu.add(const Duration(days: 1));
      c.refresh();
      expect((await store.load()).day, '2026-11-20');
    });
  });
}
