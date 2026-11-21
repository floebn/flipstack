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
    this.revived = false,
    this.flawlessHeight = 0,
    this.rotationsAt20,
  });
  final int score, height, pieces, bestCombo, rotations, cleanPlacements;

  /// Vollständig gefüllte Ebenen.
  final int layers;

  /// Die zweite Chance wurde genutzt.
  final bool revived;

  /// Grösste Höhe, die erreicht wurde, bevor die Combo zum ersten Mal riss.
  final int flawlessHeight;

  /// Anzahl der Drehungen beim Erreichen von Höhe 20 (`null` = nicht erreicht).
  final int? rotationsAt20;
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
  // Neue Zähler immer am Ende anhängen; gespeichert wird der Name.
  /// Gekaufte Designs.
  designs,

  /// Runden mit gekauftem Material, gekaufter Plattform und gekauftem
  /// Hintergrund zugleich.
  styledRounds,

  /// Verschiedene Tage, an denen eine Runde beendet wurde, und der letzte
  /// davon als Zahl JJJJMMTT.
  daysPlayed,
  lastPlayDay,
  dailyDone,
  weeklyDone,
  bestFlawlessHeight,
  bestHeightNoRevive,
  bestRoundPieces,
  bestRoundLayers,

  /// 1, sobald Höhe 20 mit höchstens 20 Drehungen erreicht wurde.
  strategist,
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
    this.reward, {
    String? series,
    this.tier = 0,
  }) : series = series ?? id;
  final String id, title, text;
  final Counter counter;
  final int target, reward;

  /// Reihe, zu der der Erfolg gehört. Das Aufgabenblatt zeigt je Reihe nur
  /// die nächste offene Stufe.
  final String series;

  /// Stufe innerhalb der Reihe (1 = erste), 0 = Einzelerfolg.
  final int tier;
}

abstract final class Achievements {
  static const _roman = ['', 'I', 'II', 'III', 'IV', 'V'];

  static String _n(int v) {
    final t = v.toString();
    return t.length <= 3
        ? t
        : '${t.substring(0, t.length - 3)}.${t.substring(t.length - 3)}';
  }

  /// Reihe in Stufen. [ids] hält die Kennungen älterer Fassungen fest, damit
  /// bereits erreichte Erfolge erhalten bleiben.
  static List<Achievement> _series(
    String key,
    String title,
    String Function(String target) text,
    Counter counter,
    List<int> targets,
    List<int> rewards, {
    Map<int, String> ids = const {},
  }) => [
    for (var i = 0; i < targets.length; i++)
      Achievement(
        ids[targets[i]] ?? '${key}_${targets[i]}',
        targets.length == 1 ? title : '$title ${_roman[i + 1]}',
        text(_n(targets[i])),
        counter,
        targets[i],
        rewards[i],
        series: key,
        tier: targets.length == 1 ? 0 : i + 1,
      ),
  ];

  /// Zahl der kaufbaren Designs (für "Sammler").
  static final int purchasable = Cosmetics.all.where((c) => c.price > 0).length;

  static final List<Achievement> all = [
    const Achievement(
      'first_stack',
      'Erster Stein',
      'Lege deinen ersten Baustein ab',
      Counter.pieces,
      1,
      20,
    ),
    // --- Leistung in einer Runde
    ..._series(
      'height',
      'Hoch hinaus',
      (t) => 'Erreiche Höhe $t',
      Counter.bestHeight,
      [10, 25, 40, 60, 80],
      [50, 150, 300, 500, 800],
      ids: {10: 'higher', 25: 'sky_high', 40: 'cloud'},
    ),
    ..._series(
      'score',
      'Punktejäger',
      (t) => 'Erreiche $t Punkte in einer Runde',
      Counter.bestScore,
      [5000, 15000, 30000, 50000],
      [100, 250, 400, 700],
      ids: {5000: 'score5k', 15000: 'score15k'},
    ),
    ..._series(
      'combo',
      'Gleichgewicht',
      (t) => 'Erreiche eine Combo von $t',
      Counter.bestCombo,
      [10, 15, 25, 40],
      [50, 100, 250, 500],
      ids: {15: 'balance'},
    ),
    ..._series(
      'marathon',
      'Marathon',
      (t) => 'Lege $t Bausteine in einer Runde ab',
      Counter.bestRoundPieces,
      [200, 400],
      [200, 500],
    ),
    ..._series(
      'round_layers',
      'Ebene für Ebene',
      (t) => 'Fülle $t Ebenen in einer Runde',
      Counter.bestRoundLayers,
      [10, 25],
      [150, 400],
    ),
    ..._series(
      'flawless',
      'Makellos',
      (t) => 'Erreiche Höhe $t, ohne die Combo zu verlieren',
      Counter.bestFlawlessHeight,
      [15],
      [250],
    ),
    ..._series(
      'no_help',
      'Ohne Hilfe',
      (t) => 'Erreiche Höhe $t ohne „Weiterspielen“',
      Counter.bestHeightNoRevive,
      [40],
      [300],
    ),
    const Achievement(
      'strategist',
      'Stratege',
      'Erreiche Höhe 20 mit höchstens 20 Drehungen',
      Counter.strategist,
      1,
      250,
    ),
    // --- Ausdauer über alle Runden
    ..._series(
      'pieces',
      'Baumeister',
      (t) => 'Lege insgesamt $t Bausteine ab',
      Counter.pieces,
      [100, 1000, 5000, 20000],
      [30, 200, 400, 800],
      ids: {1000: 'builder'},
    ),
    ..._series(
      'clean',
      'Saubere Arbeit',
      (t) => 'Lege insgesamt $t Bausteine sauber ab',
      Counter.cleanPlacements,
      [100, 500, 2500, 10000],
      [50, 150, 300, 600],
      ids: {500: 'clean500'},
    ),
    ..._series(
      'layers',
      'Lückenlos',
      (t) => 'Fülle insgesamt $t Ebenen vollständig',
      Counter.layers,
      [25, 100, 500, 2000],
      [50, 150, 300, 600],
      ids: {100: 'layers100'},
    ),
    ..._series(
      'rotations',
      'Drehmeister',
      (t) => 'Drehe die Plattform insgesamt $t-mal',
      Counter.rotations,
      [100, 1000, 5000],
      [100, 200, 400],
      ids: {100: 'rotation'},
    ),
    ..._series(
      'rounds',
      'Dranbleiber',
      (t) => 'Spiele $t Runden',
      Counter.rounds,
      [10, 50, 200, 500],
      [50, 200, 400, 800],
      ids: {50: 'persistent'},
    ),
    // --- Regelmässigkeit: Tage zählen insgesamt, nicht in Folge. Ein
    //     verpasster Tag kostet nichts.
    ..._series(
      'days',
      'Stammgast',
      (t) => 'Spiele an $t verschiedenen Tagen',
      Counter.daysPlayed,
      [7, 30, 100],
      [100, 300, 800],
    ),
    ..._series(
      'daily',
      'Pflichtbewusst',
      (t) => 'Erfülle $t Tagesaufgaben',
      Counter.dailyDone,
      [10, 50, 200],
      [100, 250, 600],
    ),
    ..._series(
      'weekly',
      'Wochenprofi',
      (t) => 'Erfülle $t Wochenaufgaben',
      Counter.weeklyDone,
      [5, 20],
      [200, 500],
    ),
    // --- Sammeln
    ..._series(
      'coins',
      'Sparfuchs',
      (t) => 'Verdiene insgesamt $t Münzen',
      Counter.coinsEarned,
      [1000, 5000, 20000],
      [100, 250, 600],
    ),
    ..._series(
      'designs',
      'Sammler',
      (t) => 'Schalte $t Designs frei',
      Counter.designs,
      [5, 15, purchasable],
      [150, 400, 1000],
    ),
    const Achievement(
      'styled',
      'Stilbewusst',
      'Spiele eine Runde mit gekauftem Material, gekaufter Plattform '
          'und gekauftem Hintergrund',
      Counter.styledRounds,
      1,
      150,
    ),
  ];

  static final Map<String, Achievement> byId = {for (final a in all) a.id: a};

  /// Je Reihe die nächste noch nicht erreichte Stufe.
  static List<Achievement> nextOpen(Set<String> achieved) {
    final seen = <String>{};
    return [
      for (final a in all)
        if (!achieved.contains(a.id) && seen.add(a.series)) a,
    ];
  }
}

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
    best(Counter.bestRoundPieces, r.pieces);
    best(Counter.bestRoundLayers, r.layers);
    best(Counter.bestFlawlessHeight, r.flawlessHeight);
    if (!r.revived) best(Counter.bestHeightNoRevive, r.height);
    final turns = r.rotationsAt20;
    if (turns != null && turns <= 20) best(Counter.strategist, 1);
    best(Counter.designs, p.owned.length);
    if (CosmeticCategory.values
        .where(
          (k) =>
              k == CosmeticCategory.material ||
              k == CosmeticCategory.platform ||
              k == CosmeticCategory.background,
        )
        .every((k) => p.equippedIn(k).price > 0)) {
      add(Counter.styledRounds, 1);
    }
    // Spieltage insgesamt (nicht in Folge)
    final today = now.year * 10000 + now.month * 100 + now.day;
    if (r.pieces > 0 && (c[Counter.lastPlayDay] ?? 0) != today) {
      c[Counter.lastPlayDay] = today;
      add(Counter.daysPlayed, 1);
    }

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
    final daily = advance(p.daily);
    add(Counter.dailyDone, doneQuests.length);
    final dailyCount = doneQuests.length;
    final weekly = advance(p.weekly);
    add(Counter.weeklyDone, doneQuests.length - dailyCount);

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
