import 'package:flipstack/game/core/piece.dart';
import 'package:flipstack/game/meta/rewards.dart';
import 'package:flipstack/l10n/tr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => lang = Lang.de);

  test('Deutsch nur auf deutschsprachigen Geräten, sonst Englisch', () {
    for (final code in ['de', 'DE', 'de_AT', 'de-CH']) {
      setLanguageFromCode(code);
      expect(lang, Lang.de, reason: code);
    }
    for (final code in ['en', 'fr', 'es', 'ja', '', 'nl']) {
      setLanguageFromCode(code);
      expect(lang, Lang.en, reason: code);
    }
  });

  test('Zahlen folgen der Sprache', () {
    lang = Lang.de;
    expect((formatInt(1234567), formatDecimal(1.5)), ('1.234.567', '1,5'));
    expect(formatInt(999), '999');
    lang = Lang.en;
    expect((formatInt(1234567), formatDecimal(1.5)), ('1,234,567', '1.5'));
  });

  test('auf Englisch bleibt kein deutscher Text in der Spiellogik', () {
    lang = Lang.en;
    final texts = <String>[
      for (final q in [...Quests.dailyPool, ...Quests.weeklyPool]) q.text,
      for (final c in Cosmetics.all) c.name,
      for (var h = 1; h <= 100; h++) ?const DifficultyCurve().changeAt(h),
    ];
    // Erfolge werden beim ersten Zugriff in der dann aktiven Sprache gebaut;
    // die App setzt die Sprache vor dem ersten Zugriff.
    final german = RegExp(
      r'[äöüÄÖÜß]|\b(Erreiche|Lege|Spiele|Fülle|Drehe|Bald|Münzen|Höhe)\b',
    );
    for (final text in texts) {
      expect(german.hasMatch(text), isFalse, reason: text);
    }
    expect(Quests.dailyPool.first.text, startsWith('Reach height'));
    expect(Cosmetics.byId['mat_stud']!.name, 'Stud');
    lang = Lang.de;
    expect(Cosmetics.byId['mat_stud']!.name, 'Noppe');
  });
}
