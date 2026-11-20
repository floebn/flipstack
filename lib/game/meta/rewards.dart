import 'dart:math';

/// Belohnungssystem (Masterbrief Abschnitt 6): Münzen, Aufgaben, Erfolge und
/// kosmetische Freischaltungen. Reines Dart ohne Flutter, vollständig testbar.
/// Münzen kaufen ausschliesslich Aussehen, nie einen Spielvorteil.

/// Was eine beendete Runde zum Fortschritt beiträgt.
class RoundSummary {
  const RoundSummary({
    required this.score,
    required this.height,
    required this.pieces,
    required this.bestCombo,
    required this.rotations,
    required this.cleanPlacements,
    required this.layers,
  });
  final int score, height, pieces, bestCombo, rotations, cleanPlacements;

  /// Vollständig gefüllte Ebenen.
  final int layers;
}

/// Zähler über alle Runden.
enum Counter {
  rounds,
  pieces,
  rotations,
  cleanPlacements,
  layers,
  score,
  coinsEarned,
  bestHeight,
  bestScore,
  bestCombo,
}

/// Wie eine Aufgabe ausgewertet wird.
enum QuestKind {
  /// Summe über alle Runden des Zeitraums.
  pieces,
  rotations,
  score,
  rounds,
  layers,
  cleanPlacements,
  coins,

  /// Bestwert innerhalb einer einzelnen Runde.
  height,
  combo,
  roundScore,

  /// Anzahl Runden, die mindestens die Höhe [QuestDef.param] erreichen.
  heightRounds,
}

class QuestDef {
  const QuestDef(
    this.id,
    this.kind,
    this.target,
    this.reward, {
    this.param = 0,
  });
  final String id;
  final QuestKind kind;
  final int target, reward, param;

  bool get isSum => switch (kind) {
    QuestKind.height || QuestKind.combo || QuestKind.roundScore => false,
    _ => true,
  };

  String get text => switch (kind) {
    QuestKind.pieces => 'Lege $target Bausteine ab',
    QuestKind.rotations => 'Drehe die Plattform $target-mal',
    QuestKind.score => 'Sammle $target Punkte',
    QuestKind.rounds => 'Spiele $target Runden',
    QuestKind.layers => 'Fülle $target Ebenen vollständig',
    QuestKind.cleanPlacements => 'Lege $target Bausteine sauber ab',
    QuestKind.coins => 'Verdiene $target Münzen',
    QuestKind.height => 'Erreiche Höhe $target',
    QuestKind.combo => 'Erreiche eine Combo von $target',
    QuestKind.roundScore => 'Erreiche $target Punkte in einer Runde',
    QuestKind.heightRounds => 'Erreiche $target-mal Höhe $param',
  };

  /// Beitrag einer Runde ([coins] = in dieser Runde verdiente Rundenmünzen).
  int contribution(RoundSummary r, int coins) => switch (kind) {
    QuestKind.pieces => r.pieces,
    QuestKind.rotations => r.rotations,
    QuestKind.score || QuestKind.roundScore => r.score,
    QuestKind.rounds => 1,
    QuestKind.layers => r.layers,
    QuestKind.cleanPlacements => r.cleanPlacements,
    QuestKind.coins => coins,
    QuestKind.height => r.height,
    QuestKind.combo => r.bestCombo,
    QuestKind.heightRounds => r.height >= param ? 1 : 0,
  };
}

/// Stand einer Aufgabe im laufenden Zeitraum.
class QuestState {
  const QuestState(this.id, [this.progress = 0, this.done = false]);
  final String id;
  final int progress;
  final bool done;

  Map<String, dynamic> toJson() => {'id': id, 'p': progress, 'd': done};
}

abstract final class Quests {
  /// In wenigen Minuten erreichbar.
  static const dailyPool = [
    QuestDef('d_height8', QuestKind.height, 8, 40),
    QuestDef('d_height12', QuestKind.height, 12, 60),
    QuestDef('d_pieces30', QuestKind.pieces, 30, 40),
    QuestDef('d_pieces60', QuestKind.pieces, 60, 60),
    QuestDef('d_rot10', QuestKind.rotations, 10, 40),
    QuestDef('d_combo5', QuestKind.combo, 5, 40),
    QuestDef('d_combo8', QuestKind.combo, 8, 60),
    QuestDef('d_score2000', QuestKind.score, 2000, 40),
    QuestDef('d_score5000', QuestKind.score, 5000, 60),
    QuestDef('d_layers3', QuestKind.layers, 3, 50),
    QuestDef('d_clean20', QuestKind.cleanPlacements, 20, 50),
    QuestDef('d_rounds2', QuestKind.rounds, 2, 40),
  ];

  /// Anspruchsvoller, über mehrere Sitzungen.
  static const weeklyPool = [
    QuestDef('w_rounds10', QuestKind.rounds, 10, 150),
    QuestDef('w_height20x3', QuestKind.heightRounds, 3, 250, param: 20),
    QuestDef('w_height10x5', QuestKind.heightRounds, 5, 150, param: 10),
    QuestDef('w_coins400', QuestKind.coins, 400, 150),
    QuestDef('w_score8000', QuestKind.roundScore, 8000, 200),
    QuestDef('w_pieces400', QuestKind.pieces, 400, 150),
    QuestDef('w_layers25', QuestKind.layers, 25, 200),
    QuestDef('w_score30000', QuestKind.score, 30000, 200),
  ];

  static const perPeriod = 3;

  static final Map<String, QuestDef> byId = {
    for (final q in [...dailyPool, ...weeklyPool]) q.id: q,
  };

  /// Tagesschlüssel in Ortszeit, z. B. "2026-11-19".
  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// Wochenschlüssel: Datum des Montags der Woche.
  static String weekKey(DateTime t) => dayKey(
    DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1)),
  );

  /// Wählt [perPeriod] Aufgaben, für denselben Schlüssel immer dieselben.
  /// Von jeder Art höchstens eine, damit die Auswahl abwechslungsreich ist.
  static List<QuestDef> pick(List<QuestDef> pool, String key) {
    final rng = Random(
      key.codeUnits.fold<int>(17, (h, c) => (h * 31 + c) & 0x3fffffff),
    );
    final out = <QuestDef>[];
    for (final q in [...pool]..shuffle(rng)) {
      if (out.any((o) => o.kind == q.kind)) continue;
      out.add(q);
      if (out.length == perPeriod) break;
    }
    return out;
  }
}

class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.text,
    this.counter,
    this.target,
    this.reward,
  );
  final String id, title, text;
  final Counter counter;
  final int target, reward;
}

abstract final class Achievements {
  static const all = [
    Achievement(
      'first_stack',
      'Erster Stein',
      'Lege deinen ersten Baustein ab',
      Counter.pieces,
      1,
      20,
    ),
    Achievement(
      'higher',
      'Es geht aufwärts',
      'Erreiche Höhe 10',
      Counter.bestHeight,
      10,
      50,
    ),
    Achievement(
      'sky_high',
      'Hoch hinaus',
      'Erreiche Höhe 25',
      Counter.bestHeight,
      25,
      150,
    ),
    Achievement(
      'cloud',
      'Über den Wolken',
      'Erreiche Höhe 40',
      Counter.bestHeight,
      40,
      300,
    ),
    Achievement(
      'balance',
      'Feines Gleichgewicht',
      'Erreiche eine Combo von 15',
      Counter.bestCombo,
      15,
      100,
    ),
    Achievement(
      'clean500',
      'Saubere Arbeit',
      'Lege 500 Bausteine sauber ab',
      Counter.cleanPlacements,
      500,
      150,
    ),
    Achievement(
      'rotation',
      'Drehmeister',
      'Drehe die Plattform 100-mal',
      Counter.rotations,
      100,
      100,
    ),
    Achievement(
      'persistent',
      'Dranbleiber',
      'Spiele 50 Runden',
      Counter.rounds,
      50,
      200,
    ),
    Achievement(
      'score5k',
      'Punktejäger',
      'Erreiche 5.000 Punkte in einer Runde',
      Counter.bestScore,
      5000,
      100,
    ),
    Achievement(
      'score15k',
      'Rekordjäger',
      'Erreiche 15.000 Punkte in einer Runde',
      Counter.bestScore,
      15000,
      250,
    ),
    Achievement(
      'layers100',
      'Lückenlos',
      'Fülle 100 Ebenen vollständig',
      Counter.layers,
      100,
      150,
    ),
    Achievement(
      'builder',
      'Baumeister',
      'Lege 1.000 Bausteine ab',
      Counter.pieces,
      1000,
      200,
    ),
  ];
}

/// [material] ist die Form und Oberfläche der Würfel, [blocks] ihre Farben;
/// beides lässt sich frei kombinieren.
enum CosmeticCategory { material, blocks, background, platform, effect }

class Cosmetic {
  const Cosmetic(this.id, this.category, this.name, this.price);
  final String id;
  final CosmeticCategory category;
  final String name;

  /// 0 = von Anfang an vorhanden.
  final int price;
}

abstract final class Cosmetics {
  static const all = [
    Cosmetic('mat_matte', CosmeticCategory.material, 'Matt', 0),
    Cosmetic('mat_pebble', CosmeticCategory.material, 'Kiesel', 700),
    Cosmetic('mat_plank', CosmeticCategory.material, 'Planke', 800),
    Cosmetic('mat_facet', CosmeticCategory.material, 'Facette', 700),
    Cosmetic('mat_concrete', CosmeticCategory.material, 'Beton', 800),
    Cosmetic('mat_fabric', CosmeticCategory.material, 'Stoff', 1000),
    Cosmetic('mat_ice', CosmeticCategory.material, 'Eis', 1400),
    Cosmetic('mat_volcano', CosmeticCategory.material, 'Vulkan', 1500),
    Cosmetic('mat_neon', CosmeticCategory.material, 'Neonglas', 1600),
    Cosmetic('mat_stud', CosmeticCategory.material, 'Noppe', 1800),
    Cosmetic('blocks_classic', CosmeticCategory.blocks, 'Klassik', 0),
    Cosmetic('blocks_arctic', CosmeticCategory.blocks, 'Arctic', 400),
    Cosmetic('blocks_forest', CosmeticCategory.blocks, 'Forest', 400),
    Cosmetic('blocks_sunset', CosmeticCategory.blocks, 'Sunset', 500),
    Cosmetic('blocks_lagoon', CosmeticCategory.blocks, 'Lagoon', 500),
    Cosmetic('blocks_lavender', CosmeticCategory.blocks, 'Lavender', 500),
    Cosmetic('blocks_candy', CosmeticCategory.blocks, 'Candy', 600),
    Cosmetic('blocks_volcano', CosmeticCategory.blocks, 'Volcano', 600),
    Cosmetic('bg_sand', CosmeticCategory.background, 'Sand', 0),
    Cosmetic('bg_dawn', CosmeticCategory.background, 'Dawn', 250),
    Cosmetic('bg_mist', CosmeticCategory.background, 'Mist', 350),
    Cosmetic('bg_dusk', CosmeticCategory.background, 'Dusk', 450),
    Cosmetic('bg_forest', CosmeticCategory.background, 'Wald', 800),
    Cosmetic('bg_autumn', CosmeticCategory.background, 'Herbst', 900),
    Cosmetic('bg_winter', CosmeticCategory.background, 'Winter', 900),
    Cosmetic('bg_underwater', CosmeticCategory.background, 'Unterwasser', 1100),
    Cosmetic('bg_space', CosmeticCategory.background, 'Weltraum', 1300),
    Cosmetic('bg_city', CosmeticCategory.background, 'Neonstadt', 1500),
    Cosmetic('platform_slate', CosmeticCategory.platform, 'Schiefer', 0),
    Cosmetic('platform_clay', CosmeticCategory.platform, 'Ton', 350),
    Cosmetic('platform_moss', CosmeticCategory.platform, 'Moos', 450),
    Cosmetic('platform_oak', CosmeticCategory.platform, 'Eiche', 800),
    Cosmetic('platform_marble', CosmeticCategory.platform, 'Marmor', 1000),
    Cosmetic('platform_glacier', CosmeticCategory.platform, 'Gletscher', 1300),
    Cosmetic(
      'platform_future',
      CosmeticCategory.platform,
      'Futuristisch',
      1500,
    ),
    Cosmetic('platform_island', CosmeticCategory.platform, 'Insel', 1700),
    Cosmetic('fx_dust', CosmeticCategory.effect, 'Staub', 0),
    Cosmetic('fx_confetti', CosmeticCategory.effect, 'Konfetti', 300),
    Cosmetic('fx_shards', CosmeticCategory.effect, 'Splitter', 500),
  ];

  static final Map<String, Cosmetic> byId = {for (final c in all) c.id: c};

  /// Stücke einer Kategorie, vom günstigsten zum teuersten (bei gleichem
  /// Preis in der Reihenfolge des Katalogs). So zeigt sie auch der Shop.
  static List<Cosmetic> of(CosmeticCategory c) {
    final items = [
      for (final x in all)
        if (x.category == c) x,
    ];
    final order = {for (var i = 0; i < items.length; i++) items[i].id: i};
    return items..sort((a, b) {
      final byPrice = a.price.compareTo(b.price);
      return byPrice != 0 ? byPrice : order[a.id]!.compareTo(order[b.id]!);
    });
  }

  static Cosmetic defaultOf(CosmeticCategory c) =>
      of(c).firstWhere((x) => x.price == 0);
}

/// Was eine Runde eingebracht hat (für den Ergebnisbildschirm).
class RoundRewards {
  const RoundRewards({
    this.roundCoins = 0,
    this.stageCoins = 0,
    this.quests = const [],
    this.achievements = const [],
  });

  /// Münzen für die Punkte der Runde.
  final int roundCoins;

  /// Münzen für erreichte Etappen (Höhe 10, 20, ...).
  final int stageCoins;
  final List<QuestDef> quests;
  final List<Achievement> achievements;

  int get total =>
      roundCoins +
      stageCoins +
      quests.fold<int>(0, (s, q) => s + q.reward) +
      achievements.fold<int>(0, (s, a) => s + a.reward);
}

/// Gesamter Belohnungsstand eines Spielers. Unveränderlich; jede Aktion
/// liefert einen neuen Stand.
class Profile {
  const Profile({
    this.coins = 0,
    this.counters = const {},
    this.owned = const {},
    this.equipped = const {},
    this.day = '',
    this.daily = const [],
    this.week = '',
    this.weekly = const [],
    this.achievements = const {},
  });

  final int coins;
  final Map<Counter, int> counters;

  /// Gekaufte Freischaltungen (kostenlose gelten immer als vorhanden).
  final Set<String> owned;
  final Map<CosmeticCategory, String> equipped;
  final String day, week;
  final List<QuestState> daily, weekly;
  final Set<String> achievements;

  static const coinsPerPoints = 100;
  static const coinsPerStage = 10;

  int counter(Counter c) => counters[c] ?? 0;

  bool owns(String id) =>
      (Cosmetics.byId[id]?.price ?? 1) == 0 || owned.contains(id);

  Cosmetic equippedIn(CosmeticCategory c) {
    final item = Cosmetics.byId[equipped[c]];
    return item != null && item.category == c && owns(item.id)
        ? item
        : Cosmetics.defaultOf(c);
  }

  /// Günstigste noch nicht gekaufte Freischaltung (Ziel der Fortschrittsanzeige).
  Cosmetic? get nextUnlock {
    Cosmetic? best;
    for (final c in Cosmetics.all) {
      if (owns(c.id)) continue;
      if (best == null || c.price < best.price) best = c;
    }
    return best;
  }

  Profile _copy({
    int? coins,
    Map<Counter, int>? counters,
    Set<String>? owned,
    Map<CosmeticCategory, String>? equipped,
    String? day,
    List<QuestState>? daily,
    String? week,
    List<QuestState>? weekly,
    Set<String>? achievements,
  }) => Profile(
    coins: coins ?? this.coins,
    counters: counters ?? this.counters,
    owned: owned ?? this.owned,
    equipped: equipped ?? this.equipped,
    day: day ?? this.day,
    daily: daily ?? this.daily,
    week: week ?? this.week,
    weekly: weekly ?? this.weekly,
    achievements: achievements ?? this.achievements,
  );

  /// Stellt sicher, dass Tages- und Wochenaufgaben zum Datum [now] gehören.
  /// Ein verpasster Tag kostet nichts: Es gibt einfach neue Aufgaben.
  Profile refreshed(DateTime now) {
    final d = Quests.dayKey(now), w = Quests.weekKey(now);
    if (d == day && w == week) return this;
    return _copy(
      day: d,
      daily: d == day
          ? daily
          : [
              for (final q in Quests.pick(Quests.dailyPool, d))
                QuestState(q.id),
            ],
      week: w,
      weekly: w == week
          ? weekly
          : [
              for (final q in Quests.pick(Quests.weeklyPool, w))
                QuestState(q.id),
            ],
    );
  }

  /// Verbucht eine beendete Runde.
  (Profile, RoundRewards) recordRound(RoundSummary r, DateTime now) {
    final p = refreshed(now);
    final roundCoins = r.pieces == 0 ? 0 : max(1, r.score ~/ coinsPerPoints);
    final stageCoins = (r.height ~/ 10) * coinsPerStage;

    final c = {...p.counters};
    void add(Counter k, int v) => c[k] = (c[k] ?? 0) + v;
    void best(Counter k, int v) => c[k] = max(c[k] ?? 0, v);
    add(Counter.rounds, 1);
    add(Counter.pieces, r.pieces);
    add(Counter.rotations, r.rotations);
    add(Counter.cleanPlacements, r.cleanPlacements);
    add(Counter.layers, r.layers);
    add(Counter.score, r.score);
    best(Counter.bestHeight, r.height);
    best(Counter.bestScore, r.score);
    best(Counter.bestCombo, r.bestCombo);

    final doneQuests = <QuestDef>[];
    List<QuestState> advance(List<QuestState> states) => [
      for (final s in states)
        () {
          final q = Quests.byId[s.id];
          if (q == null || s.done) return s;
          final v = q.contribution(r, roundCoins + stageCoins);
          final progress = min(
            q.target,
            q.isSum ? s.progress + v : max(s.progress, v),
          );
          final done = progress >= q.target;
          if (done) doneQuests.add(q);
          return QuestState(s.id, progress, done);
        }(),
    ];
    final daily = advance(p.daily), weekly = advance(p.weekly);

    final unlocked = <Achievement>[
      for (final a in Achievements.all)
        if (!p.achievements.contains(a.id) && (c[a.counter] ?? 0) >= a.target)
          a,
    ];
    final rewards = RoundRewards(
      roundCoins: roundCoins,
      stageCoins: stageCoins,
      quests: doneQuests,
      achievements: unlocked,
    );
    add(Counter.coinsEarned, rewards.total);
    return (
      p._copy(
        coins: p.coins + rewards.total,
        counters: c,
        daily: daily,
        weekly: weekly,
        achievements: {...p.achievements, for (final a in unlocked) a.id},
      ),
      rewards,
    );
  }

  /// Schreibt zusätzliche Münzen gut (z. B. Verdopplung nach belohnter
  /// Werbung).
  Profile withBonus(int amount) => amount <= 0
      ? this
      : _copy(
          coins: coins + amount,
          counters: {
            ...counters,
            Counter.coinsEarned: counter(Counter.coinsEarned) + amount,
          },
        );

  /// Kauft eine Freischaltung und wählt sie aus. `null`, wenn das nicht geht.
  Profile? buy(String id) {
    final item = Cosmetics.byId[id];
    if (item == null || owns(id) || coins < item.price) return null;
    return _copy(
      coins: coins - item.price,
      owned: {...owned, id},
      equipped: {...equipped, item.category: id},
    );
  }

  /// Wählt eine vorhandene Freischaltung aus. `null`, wenn sie fehlt.
  Profile? equip(String id) {
    final item = Cosmetics.byId[id];
    if (item == null || !owns(id)) return null;
    return _copy(equipped: {...equipped, item.category: id});
  }

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'counters': {
      for (final c in Counter.values)
        if (counters.containsKey(c)) c.name: counters[c],
    },
    'owned': owned.toList(),
    'equipped': {for (final e in equipped.entries) e.key.name: e.value},
    'day': day,
    'daily': [for (final q in daily) q.toJson()],
    'week': week,
    'weekly': [for (final q in weekly) q.toJson()],
    'achievements': achievements.toList(),
  };

  /// Unbekannte oder fehlerhafte Einträge werden übergangen (robust gegen
  /// alte Stände und entfernte Inhalte).
  factory Profile.fromJson(Map<String, dynamic> j) {
    int nat(Object? v) => v is int && v >= 0 ? v : 0;
    Map<String, dynamic> map(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    List<QuestState> quests(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map && Quests.byId.containsKey(e['id']))
            QuestState(e['id'] as String, nat(e['p']), e['d'] == true),
    ];
    return Profile(
      coins: nat(j['coins']),
      counters: {
        for (final c in Counter.values)
          if (map(j['counters'])[c.name] != null)
            c: nat(map(j['counters'])[c.name]),
      },
      owned: {
        for (final id in strings(j['owned']))
          if (Cosmetics.byId.containsKey(id)) id,
      },
      equipped: {
        for (final c in CosmeticCategory.values)
          if (Cosmetics.byId[map(j['equipped'])[c.name]]?.category == c)
            c: map(j['equipped'])[c.name] as String,
      },
      day: j['day'] is String ? j['day'] as String : '',
      daily: quests(j['daily']),
      week: j['week'] is String ? j['week'] as String : '',
      weekly: quests(j['weekly']),
      achievements: strings(j['achievements']).toSet(),
    );
  }
}
