import 'dart:math' as math;
import 'dart:ui';

/// Farbstimmung eines Hintergrunds. Alle Varianten sind hell und ruhig, damit
/// Spielfeld und dunkle Schrift immer gut lesbar bleiben.
class BackgroundTheme {
  const BackgroundTheme(
    this.name,
    this.top,
    this.bottom,
    this.glow,
    this.shape,
  );
  final String name;
  final Color top, bottom;

  /// Lichtschein hinter dem Turm (hebt das Spielfeld hervor).
  final Color glow;

  /// Farbe der dezenten geometrischen Formen.
  final Color shape;

  static const sand = BackgroundTheme(
    'Sand',
    Color(0xFFF6EFE2),
    Color(0xFFE9DCC8),
    Color(0xFFFFFBF2),
    Color(0xFFD9B98C),
  );
  static const dawn = BackgroundTheme(
    'Dawn',
    Color(0xFFFBEADD),
    Color(0xFFF1D2C6),
    Color(0xFFFFF6EC),
    Color(0xFFE59A85),
  );
  static const mist = BackgroundTheme(
    'Mist',
    Color(0xFFEAF1EC),
    Color(0xFFD3E2DC),
    Color(0xFFF8FCF9),
    Color(0xFF6FB6A8),
  );
  static const dusk = BackgroundTheme(
    'Dusk',
    Color(0xFFEFE8F2),
    Color(0xFFDCD0E2),
    Color(0xFFFBF7FC),
    Color(0xFF9D8BC7),
  );

  static const all = [sand, dawn, mist, dusk];
}

/// Zeichnet den Hintergrund prozedural: Verlauf, Lichtschein und wenige grosse,
/// isometrisch ausgerichtete Rauten, die sich kaum merklich bewegen.
/// Auflösungsunabhängig und ohne Bilddateien.
class BackgroundPainter {
  BackgroundTheme _theme = BackgroundTheme.sand;
  Size _size = Size.zero;
  Shader? _gradient;
  final Paint _paint = Paint();

  // (x, y relativ zur Bildschirmgrösse, Grösse relativ zur Breite, Deckkraft, Phase)
  static const _shapes = [
    (0.10, 0.20, 0.62, 0.10, 0.0),
    (0.92, 0.36, 0.48, 0.08, 1.7),
    (0.18, 0.80, 0.80, 0.07, 3.1),
    (0.86, 0.90, 0.40, 0.09, 4.4),
  ];

  BackgroundTheme get theme => _theme;
  set theme(BackgroundTheme t) {
    _theme = t;
    _gradient = null;
  }

  void render(Canvas canvas, Size size, double time, Offset focus) {
    if (_gradient == null || size != _size) {
      _size = size;
      _gradient = Gradient.linear(Offset.zero, Offset(0, size.height), [
        _theme.top,
        _theme.bottom,
      ]);
    }
    final full = Offset.zero & size;
    canvas.drawRect(full, _paint..shader = _gradient);
    _paint.shader = null;

    for (final (fx, fy, fs, alpha, phase) in _shapes) {
      final drift = math.sin(time * 0.25 + phase) * size.width * 0.012;
      final c = Offset(fx * size.width + drift, fy * size.height - drift * 0.5);
      final w = fs * size.width / 2,
          h = w * 0.57735; // Rautenverhältnis der Isometrie
      final path = Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + w, c.dy)
        ..lineTo(c.dx, c.dy + h)
        ..lineTo(c.dx - w, c.dy)
        ..close();
      canvas.drawPath(
        path,
        _paint..color = _theme.shape.withValues(alpha: alpha),
      );
    }

    final r = size.width * 0.85;
    canvas.drawCircle(
      focus,
      r,
      Paint()
        ..shader = Gradient.radial(focus, r, [
          _theme.glow.withValues(alpha: 0.85),
          _theme.glow.withValues(alpha: 0),
        ]),
    );
  }
}
