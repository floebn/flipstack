import 'dart:math' as math;
import 'dart:ui';

/// Bewegte Kleinteile eines Hintergrunds.
enum BackgroundParticles { none, pollen, leaves, snow, stars, bubbles, traffic }

/// Farbstimmung eines Hintergrunds. Alle Varianten sind hell und ruhig, damit
/// Spielfeld und dunkle Schrift immer gut lesbar bleiben.
class BackgroundTheme {
  const BackgroundTheme(
    this.name,
    this.top,
    this.bottom,
    this.glow,
    this.shape, {
    this.scene,
    this.particles = BackgroundParticles.none,
    this.dark = false,
    this.rays = false,
  });
  final String name;
  final Color top, bottom;

  /// Lichtschein hinter dem Turm (hebt das Spielfeld hervor).
  final Color glow;

  /// Farbe der dezenten geometrischen Formen.
  final Color shape;

  /// Gerenderte Szenerie am unteren Bildrand (Datei in assets/backgrounds/).
  /// Themen mit Szenerie zeichnen keine Rauten.
  final String? scene;
  final BackgroundParticles particles;

  /// Schräge Lichtbahnen von oben (Unterwasser).
  final bool rays;

  /// Dunkles Thema: Schrift und Symbole auf dem Hintergrund werden hell.
  final bool dark;

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

  // Themen mit Szenerie: Der Verlauf endet unten in der Dunstfarbe, zu der
  // die entfernten Staffeln der Szenerie aufgehellt sind.
  static const forest = BackgroundTheme(
    'Wald',
    Color(0xFFEEF5EC),
    Color(0xFFDCEBDD),
    Color(0xFFFBFEF9),
    Color(0xFF7FAF7C),
    scene: 'forest.png',
    particles: BackgroundParticles.pollen,
  );
  static const autumn = BackgroundTheme(
    'Herbst',
    Color(0xFFFBEEDD),
    Color(0xFFF6E2C8),
    Color(0xFFFFF8EC),
    Color(0xFFE2703A),
    scene: 'autumn.png',
    particles: BackgroundParticles.leaves,
  );
  static const winter = BackgroundTheme(
    'Winter',
    Color(0xFFF0F5FA),
    Color(0xFFE3ECF5),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    scene: 'winter.png',
    particles: BackgroundParticles.snow,
  );
  static const space = BackgroundTheme(
    'Weltraum',
    Color(0xFF0E1522),
    Color(0xFF1B2536),
    Color(0xFF51648C),
    Color(0xFFFFFFFF),
    scene: 'space.png',
    particles: BackgroundParticles.stars,
    dark: true,
  );

  static const underwater = BackgroundTheme(
    'Unterwasser',
    Color(0xFFDFF3F5),
    Color(0xFFBFE4E8),
    Color(0xFFF4FCFC),
    Color(0xFFFFFFFF),
    scene: 'underwater.png',
    particles: BackgroundParticles.bubbles,
    rays: true,
  );
  static const city = BackgroundTheme(
    'Neonstadt',
    Color(0xFF100D22),
    Color(0xFF1A1632),
    Color(0xFF5A4C9A),
    Color(0xFFFFFFFF),
    scene: 'city.png',
    particles: BackgroundParticles.traffic,
    dark: true,
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
  final Paint _scenePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Geladenes Bild der Szenerie des aktuellen Themas (oder `null`).
  Image? scene;

  // Feste Zufallswerte je Partikel: (x, y, Grösse, Tempo, Phase)
  static final List<(double, double, double, double, double)> _seeds = () {
    final rng = math.Random(42);
    return [
      for (var i = 0; i < 70; i++)
        (
          rng.nextDouble(),
          rng.nextDouble(),
          rng.nextDouble(),
          rng.nextDouble(),
          rng.nextDouble() * math.pi * 2,
        ),
    ];
  }();

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

  /// [sceneBottom] ist die Unterkante der Szenerie (im Shop liegt sie über
  /// der Tafel, sonst am unteren Bildrand).
  void render(
    Canvas canvas,
    Size size,
    double time,
    Offset focus, {
    double? sceneBottom,
  }) {
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

    if (_theme.particles == BackgroundParticles.stars) {
      _stars(canvas, size, time);
    }
    for (final (fx, fy, fs, alpha, phase)
        in _theme.scene == null
            ? _shapes
            : const <(double, double, double, double, double)>[]) {
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

    if (_theme.rays) _rays(canvas, size, time);
    final img = scene;
    if (img != null) {
      final h = size.width * img.height / img.width;
      final bottom = sceneBottom ?? size.height;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, bottom - h, size.width, h),
        _scenePaint,
      );
    }

    final r = size.width * 0.85;
    final glow = _theme.dark ? 0.35 : 0.85;
    canvas.drawCircle(
      focus,
      r,
      Paint()
        ..shader = Gradient.radial(focus, r, [
          _theme.glow.withValues(alpha: glow),
          _theme.glow.withValues(alpha: 0),
        ]),
    );
    _particles(canvas, size, time);
  }

  /// Vier breite, sehr blasse Lichtbahnen, die langsam pendeln.
  void _rays(Canvas canvas, Size size, double time) {
    for (var i = 0; i < 4; i++) {
      final (x0, _, s, speed, phase) = _seeds[i];
      final sway = math.sin(time * (0.12 + speed * 0.1) + phase) * 0.04;
      final top = (0.08 + i * 0.26 + x0 * 0.08 + sway) * size.width;
      final w = (0.07 + s * 0.08) * size.width;
      final lean = size.width * 0.34;
      final path = Path()
        ..moveTo(top, 0)
        ..lineTo(top + w, 0)
        ..lineTo(top + w * 1.9 - lean, size.height * 0.78)
        ..lineTo(top - w * 0.9 - lean, size.height * 0.78)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            Offset.zero,
            Offset(0, size.height * 0.78),
            [const Color(0x38FFFFFF), const Color(0x00FFFFFF)],
          ),
      );
    }
  }

  void _stars(Canvas canvas, Size size, double time) {
    for (final (x, y, s, speed, phase) in _seeds) {
      final twinkle = 0.55 + 0.45 * math.sin(time * (0.6 + speed) + phase);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height * 0.8),
        0.6 + s * 1.3,
        _paint..color = Color.fromRGBO(255, 255, 255, 0.25 + 0.6 * twinkle * s),
      );
    }
  }

  /// Wenige, langsame Teilchen. Sie bleiben blass, damit sie das Spielfeld
  /// nicht stören.
  void _particles(Canvas canvas, Size size, double time) {
    final kind = _theme.particles;
    if (kind == BackgroundParticles.none || kind == BackgroundParticles.stars) {
      return;
    }
    final count = switch (kind) {
      BackgroundParticles.snow => 34,
      BackgroundParticles.traffic => 9,
      _ => 16,
    };
    for (var i = 0; i < count; i++) {
      final (x0, y0, s, speed, phase) = _seeds[i];
      final sway = math.sin(time * (0.4 + speed * 0.5) + phase);
      switch (kind) {
        case BackgroundParticles.snow:
          final y = (y0 + time * (0.025 + speed * 0.03)) % 1.0;
          canvas.drawCircle(
            Offset((x0 + sway * 0.015) * size.width, y * size.height),
            1.2 + s * 2.0,
            _paint..color = Color.fromRGBO(255, 255, 255, 0.55 + 0.35 * s),
          );
        case BackgroundParticles.pollen:
          final y = (y0 - time * (0.006 + speed * 0.008)) % 1.0;
          canvas.drawCircle(
            Offset((x0 + sway * 0.02) * size.width, y * size.height),
            1.0 + s * 1.6,
            _paint..color = Color.fromRGBO(255, 255, 240, 0.5 + 0.3 * s),
          );
        case BackgroundParticles.leaves:
          final y = (y0 + time * (0.018 + speed * 0.02)) % 1.0;
          final c = Offset((x0 + sway * 0.04) * size.width, y * size.height);
          canvas
            ..save()
            ..translate(c.dx, c.dy)
            ..rotate(time * (0.5 + speed) + phase);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: 6 + s * 5,
                height: 3 + s * 2.5,
              ),
              const Radius.circular(2),
            ),
            _paint
              ..color =
                  (i.isEven ? const Color(0xFFE2703A) : const Color(0xFFE9A23B))
                      .withValues(alpha: 0.55),
          );
          canvas.restore();
        case BackgroundParticles.bubbles:
          final y = (y0 - time * (0.02 + speed * 0.03)) % 1.0;
          canvas.drawCircle(
            Offset((x0 + sway * 0.012) * size.width, y * size.height),
            2.0 + s * 4.0,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Color.fromRGBO(255, 255, 255, 0.55 + 0.3 * s),
          );
        case BackgroundParticles.traffic:
          // Lichtspuren ferner Fahrzeuge, abwechselnd in beide Richtungen
          final dir = i.isEven ? 1.0 : -1.0;
          final x = ((x0 + dir * time * (0.03 + speed * 0.05)) % 1.2) - 0.1;
          final y = (0.50 + y0 * 0.22) * size.height;
          final len = (14 + s * 22) * dir;
          final c = const [
            Color(0xFFFF4FA3),
            Color(0xFF4FE3F0),
            Color(0xFFF1BD58),
          ][i % 3];
          canvas.drawLine(
            Offset(x * size.width, y),
            Offset(x * size.width - len, y),
            Paint()
              ..strokeWidth = 1.6 + s
              ..strokeCap = StrokeCap.round
              ..shader = Gradient.linear(
                Offset(x * size.width, y),
                Offset(x * size.width - len, y),
                [c.withValues(alpha: 0.8), c.withValues(alpha: 0)],
              ),
          );
        default:
      }
    }
  }
}
