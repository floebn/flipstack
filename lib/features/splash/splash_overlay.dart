import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/tr.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

/// Die drei Bilder des Startbildschirms. Sie werden vor dem ersten Bild der
/// App geladen, damit der Übergang vom nativen Startbild nicht flackert.
class SplashArt {
  const SplashArt(this.base, this.piece, this.done);

  /// Turm mit Lücke, der fallende Stein, der fertige Turm. Alle drei sind
  /// deckungsgleich gerendert (tools/blender/render_splash.py).
  final ui.Image base, piece, done;

  static Future<SplashArt> load() async {
    Future<ui.Image> image(String name) async {
      final data = await rootBundle.load('assets/ui/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    final images = await Future.wait([
      image('splash_base'),
      image('splash_piece'),
      image('splash_final'),
    ]);
    return SplashArt(images[0], images[1], images[2]);
  }
}

/// Startbildschirm: Ein Stein fällt in die letzte Lücke des Turms, beim
/// Aufsetzen gibt es Staub, einen Lichtring und Funken, danach erscheint der
/// Schriftzug an der Stelle, an der er auch im Hauptmenü steht.
///
/// Der Turm steht anfangs genau dort, wo ihn das native Startbild zeigt
/// (Bildschirmmitte, [towerSize] breit). Ein Tipp überspringt die Animation.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.art, required this.onDone});

  final SplashArt art;
  final VoidCallback onDone;

  /// Kantenlänge des Turmbilds; muss zum LaunchImage (300 pt) passen.
  static const towerSize = 300.0;

  // Ablauf in Sekunden.
  static const fallStart = 0.30;
  static const landing = 0.85;
  static const titleStart = 1.10;
  static const fadeStart = 2.25;
  static const total = 2.60;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (SplashOverlay.total * 1000).round()),
  );
  bool _hapticDone = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  void _onTick() {
    if (!_hapticDone && _time >= SplashOverlay.landing) {
      _hapticDone = true;
      HapticFeedback.lightImpact();
    }
  }

  double get _time => _c.value * SplashOverlay.total;

  /// Springt ans Ausblenden.
  void _skip() {
    final at = SplashOverlay.fadeStart / SplashOverlay.total;
    if (_c.value < at) {
      _hapticDone = true;
      _c.forward(from: at);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final time = _time;
          final fade =
              ((time - SplashOverlay.fadeStart) /
                      (SplashOverlay.total - SplashOverlay.fadeStart))
                  .clamp(0.0, 1.0);
          return Opacity(
            opacity: 1 - Curves.easeIn.transform(fade),
            child: ColoredBox(
              color: const Color(0xFFEFE6D6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _SplashPainter(widget.art, time)),
                  SafeArea(child: _title(time)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Schriftzug und Unterzeile, gesetzt wie im Hauptmenü.
  Widget _title(double time) {
    final k = ((time - SplashOverlay.titleStart) / 0.5).clamp(0.0, 1.0);
    final sub = ((time - SplashOverlay.titleStart - 0.3) / 0.4).clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(k);
    return Align(
      alignment: const Alignment(0, -0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: Curves.easeOut.transform(k),
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - pop)),
              child: Transform.scale(
                scale: 0.9 + 0.1 * pop,
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'FLIP',
                        style: TextStyle(color: FsColors.navy),
                      ),
                      TextSpan(
                        text: 'STACK',
                        style: TextStyle(color: FsColors.mint),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 56,
                    height: 1,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: Curves.easeOut.transform(sub),
            child: Text(
              t(
                'DREHEN  ·  STAPELN  ·  HOCH HINAUS',
                'ROTATE  ·  STACK  ·  AIM HIGH',
              ),
              style: fsLabel.copyWith(
                fontSize: 11.5,
                color: FsColors.navy.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.art, this.t);

  final SplashArt art;
  final double t;

  static const _colors = [
    FsColors.mint,
    Color(0xFFF27C65),
    Color(0xFFF1BD58),
    Color(0xFF5FA8D8),
    Color(0xFF9585CC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const side = SplashOverlay.towerSize;
    final box = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      art.base.width.toDouble(),
      art.base.height.toDouble(),
    );
    final smooth = Paint()..filterQuality = FilterQuality.medium;
    final e = t - SplashOverlay.landing; // Zeit seit dem Aufsetzen

    // Mitte der oberen Ebene und Fuß der Plattform im Turmbild.
    final top = Offset(box.center.dx, box.top + side * 0.40);
    final foot = box.top + side * 0.86;

    if (e < 0) {
      canvas.drawImageRect(art.base, src, box, smooth);
      // Der Stein fällt beschleunigt von oben ins Bild.
      final k =
          ((t - SplashOverlay.fallStart) /
                  (SplashOverlay.landing - SplashOverlay.fallStart))
              .clamp(0.0, 1.0);
      if (k > 0) {
        final drop = size.height * 0.5 + side * 0.4;
        final dy = -drop * (1 - k * k);
        canvas.drawImageRect(
          art.piece,
          src,
          box.shift(Offset(0, dy)),
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, (k * 5).clamp(0.0, 1.0)),
        );
      }
      return;
    }

    // Aufsetzen: der Turm federt kurz ein, verankert am Fuß der Plattform.
    final s = (e / 0.42).clamp(0.0, 1.0);
    final squash = 1 - 0.075 * math.sin(math.pi * s) * (1 - s) * 1.6;
    canvas.save();
    canvas.translate(box.center.dx, foot);
    canvas.scale(2 - squash, squash);
    canvas.translate(-box.center.dx, -foot);
    canvas.drawImageRect(art.done, src, box, smooth);
    canvas.restore();

    // Lichtringe breiten sich flach auf der Ebene aus.
    for (final (delay, color) in [(0.0, Colors.white), (0.09, FsColors.mint)]) {
      final r = ((e - delay) / 0.6).clamp(0.0, 1.0);
      if (r <= 0 || r >= 1) continue;
      final radius = side * (0.16 + 0.5 * Curves.easeOutCubic.transform(r));
      canvas.drawOval(
        Rect.fromCenter(center: top, width: radius * 2, height: radius * 1.15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - r) + 1
          ..color = color.withValues(alpha: 0.85 * (1 - r)),
      );
    }

    // Staub quillt am Rand der Ebene hervor.
    final d = (e / 0.7).clamp(0.0, 1.0);
    if (d < 1) {
      final dust = Paint();
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * 2 * math.pi + 0.3;
        final reach = side * (0.2 + 0.2 * Curves.easeOut.transform(d));
        final p =
            top +
            Offset(
              math.cos(a) * reach,
              math.sin(a) * reach * 0.58 + side * 0.06,
            );
        dust.color = Color.fromRGBO(255, 251, 243, 0.8 * (1 - d));
        canvas.drawCircle(
          p,
          side * (0.022 + 0.03 * d) * (1 + (i % 3) * 0.3),
          dust,
        );
      }
    }

    // Funken in den Spielfarben fliegen hoch und fallen wieder.
    final f = (e / 0.95).clamp(0.0, 1.0);
    if (f < 1) {
      final spark = Paint();
      for (var i = 0; i < 16; i++) {
        final a = -math.pi / 2 + (i - 7.5) / 8 * 1.25;
        final speed = side * (0.55 + (i * 37 % 10) / 22);
        final x = math.cos(a) * speed * f;
        final y = math.sin(a) * speed * f + side * 0.75 * f * f;
        final c = top + Offset(x, y);
        final r = side * 0.016 * (1 + (i % 4) * 0.22) * (1 - f * 0.4);
        spark.color = _colors[i % _colors.length].withValues(
          alpha: (1 - f * f).clamp(0.0, 1.0),
        );
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(f * 5 + i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2),
            Radius.circular(r * 0.35),
          ),
          spark,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t;
}
