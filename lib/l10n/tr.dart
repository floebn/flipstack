/// Sprache der App. Reines Dart, damit auch die Spiellogik (Aufgaben,
/// Erfolge, Ansagen) sie verwenden kann.
///
/// Es gibt zwei Sprachen: Deutsch auf deutschsprachigen Geräten, sonst
/// Englisch. Die Texte stehen an der Stelle, an der sie gebraucht werden:
/// `t('Spielen', 'Play')`.
enum Lang { de, en }

/// Aktive Sprache. Wird beim Start aus der Gerätesprache gesetzt
/// ([setLanguageFromCode]); Tests laufen auf Deutsch.
Lang lang = Lang.de;

/// Deutsch für Geräte mit deutscher Sprache, sonst Englisch.
void setLanguageFromCode(String languageCode) {
  lang = languageCode.toLowerCase().startsWith('de') ? Lang.de : Lang.en;
}

/// Liefert den Text in der aktiven Sprache.
String t(String de, String en) => lang == Lang.de ? de : en;

/// Ganze Zahl mit Tausendertrennzeichen der Sprache (1.000 bzw. 1,000).
String formatInt(int v) {
  final digits = v.abs().toString();
  final sep = lang == Lang.de ? '.' : ',';
  final out = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(sep);
    out.write(digits[i]);
  }
  return out.toString();
}

/// Dezimalzahl mit einer Nachkommastelle (1,5 bzw. 1.5).
String formatDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return lang == Lang.de ? s.replaceAll('.', ',') : s;
}
