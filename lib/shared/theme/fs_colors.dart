import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Der gewählte Hintergrund ist dunkel: Schrift und Symbole, die direkt auf
/// dem Hintergrund stehen, werden hell. Gesetzt vom Spiel.
final ValueNotifier<bool> fsDarkBackground = ValueNotifier(false);

/// Verbindliches Farbsystem von FLIPSTACK (siehe docs/ART_GUIDELINES.md).
abstract final class FsColors {
  // Grundfarben aus dem Masterbrief
  static const navy = Color(0xFF202B38);
  static const cream = Color(0xFFF2EEE5);
  static const mint = Color(0xFF35B6A4);
  static const coral = Color(0xFFF27C65);
  static const amber = Color(0xFFF1BD58);

  // Ergänzungen, auf gleiche Helligkeit und Sättigung abgestimmt
  static const sky = Color(0xFF5FA8D8);
  static const plum = Color(0xFF9585CC);
  static const leaf = Color(0xFF8CBF6B);
  static const rose = Color(0xFFE88CA3);

  /// Creme für Würfel: etwas dunkler als die UI-Creme, damit die Oberseite
  /// im Licht nicht zu reinem Weiss ausbrennt.
  static const blockCream = Color(0xFFE6DFCF);

  /// Schrift direkt auf dem Hintergrund (nicht auf Karten).
  static Color get onBackground => fsDarkBackground.value ? cream : navy;

  /// Gegenfarbe zu [onBackground] (Symbol auf einem Knopf in dieser Farbe).
  static Color get onBackgroundInverse => fsDarkBackground.value ? navy : cream;
  static Color get onBackgroundMuted =>
      fsDarkBackground.value ? const Color(0xB3F2EEE5) : textMuted;

  // Bedeutungsfarben der Oberfläche
  static const text = navy;
  static const textMuted = Color(0x99202B38);
  static const action = mint; // Hauptaktion, Erfolg
  static const error = Color(0xFFE5484D); // ungültige Position
  static const warning = amber; // Vorwarnung, Höhengrenze
  static const reward = amber; // Combo, Belohnungen
  static const highlight = coral; // Bestwert, Akzente, Orientierungsmarke
  static const disabled = Color(0xFFB9C4C0);

  /// Blockfarben; der Index ist `PieceShape.color`.
  static const blocks = [mint, coral, amber, blockCream, sky, plum, leaf, rose];
}
