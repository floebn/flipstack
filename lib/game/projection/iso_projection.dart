import 'dart:math' as math;
import 'dart:ui';

/// Zentrale isometrische Projektion. EINZIGE Stelle mit Projektionsmathematik.
///
/// Weltkoordinaten: 1 Einheit = 1 Würfelkante, Plattformmitte im Ursprung,
/// Plattform-Oberseite bei z = 0. Die Kamera ist fest (echte Isometrie,
/// identisch zur Blender-Kamera in tools/blender/config.json). Die Drehung der
/// Plattform ist ausschliesslich der Parameter [theta] (Bogenmass, um die
/// z-Achse, positiv = gegen den Uhrzeigersinn von oben gesehen).
class IsoProjection {
  IsoProjection({required this.origin, required this.unit});

  /// Bildschirmposition des Weltursprungs.
  Offset origin;

  /// Bildschirmpixel pro Welteinheit.
  double unit;

  static const double _kx = 0.7071067811865476; // cos 45°
  static const double _ky = 0.4082482904638631; // cos 45° · cos(tilt)
  static const double _kz = 0.8164965809277260; // sin(tilt), tilt = 54,7356°

  /// Dreht einen Punkt in Plattformkoordinaten um [theta] in Weltkoordinaten.
  static (double, double) rotate(double x, double y, double theta) {
    final c = math.cos(theta), s = math.sin(theta);
    return (x * c - y * s, x * s + y * c);
  }

  /// Projiziert einen Punkt in Plattformkoordinaten auf den Bildschirm.
  Offset project(double x, double y, double z, [double theta = 0]) {
    final (wx, wy) = rotate(x, y, theta);
    return projectWorld(wx, wy, z);
  }

  /// Projiziert einen bereits gedrehten Weltpunkt.
  Offset projectWorld(double wx, double wy, double z) => Offset(
    origin.dx + (wx + wy) * _kx * unit,
    origin.dy + ((wx - wy) * _ky - z * _kz) * unit,
  );

  /// Bildschirmversatz einer Höheneinheit (nach oben).
  double get unitHeight => _kz * unit;

  /// Rechnet eine Fingerbewegung auf dem Bildschirm in eine Bewegung auf der
  /// Bodenebene um (Welteinheiten entlang der kamerafesten Rasterachsen).
  (double, double) groundDelta(Offset screenDelta) {
    final a = screenDelta.dx / (_kx * unit); // = dx + dy
    final b = screenDelta.dy / (_ky * unit); // = dx - dy
    return ((a + b) / 2, (a - b) / 2);
  }

  /// Tiefe für die Painter-Sortierung: grösser = näher an der Kamera
  /// = später zeichnen.
  static double depth(double x, double y, double z, [double theta = 0]) {
    final (wx, wy) = rotate(x, y, theta);
    return wx - wy + z;
  }
}
