import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart';

/// In Blender gerenderte Sprites samt Metadaten (assets/sprites/sprites.json).
///
/// Es gibt nur EIN graues Würfel-Sprite. Die Blockfarbe entsteht durch
/// Einfärben zur Laufzeit ([tint]); das entspricht dem diffusen Material aus
/// Blender (Albedo × Licht) und erlaubt beliebig viele Farben ohne
/// zusätzlichen Bildspeicher.
class SpriteSet {
  SpriteSet._();

  late final double ppu;
  late final int frames;
  late final int angleStepDeg;
  late final int atlasCols;
  late final double cubeSize;
  late final Size tileSize;
  late final double tileCenterZ;
  late final double platformTargetZ;
  late final List<double> sunDir;

  /// Grauer Würfel, Atlas über die Drehwinkel.
  late final Image cube;
  late final Image marker;

  /// Eckpfosten (drehsymmetrisch).
  late final Image peg;
  late final double pegCenterZ;
  late final double pegOffset;

  /// Plattform im Ruhezustand (volle Auflösung).
  late final Image platformStill;

  /// Plattform während der Drehung (um [platformFrameScale] verkleinert).
  late final List<Image> platform;
  late final double platformFrameScale;

  late List<Color> palette;

  /// Farbfilter je Blockfarbe.
  late List<ColorFilter> tint;

  /// Abgedunkelte Blockfarbe für die Fugen zwischen Würfeln.
  late List<Color> shade;
  late final ColorFilter invalidTint;
  late final double _gray;

  static Future<SpriteSet> load(List<Color> palette) async {
    final images = Images(prefix: 'assets/sprites/');
    final meta = jsonDecode(
      await rootBundle.loadString('assets/sprites/sprites.json'),
    ) as Map<String, dynamic>;
    double d(Object? v) => (v as num).toDouble();
    final s = SpriteSet._()
      ..ppu = d(meta['ppu'])
      ..frames = meta['frames'] as int
      ..angleStepDeg = meta['angleStepDeg'] as int
      ..atlasCols = meta['atlasCols'] as int
      ..cubeSize = d(meta['cube']['w'])
      .._gray = d(meta['cube']['grayLevel'])
      ..tileSize = Size(d(meta['tile']['w']), d(meta['tile']['h']))
      ..tileCenterZ = d(meta['tile']['centerZ'])
      ..pegCenterZ = d(meta['peg']['centerZ'])
      ..pegOffset = d(meta['peg']['offset'])
      ..platformTargetZ = d(meta['platform']['targetZ'])
      ..platformFrameScale = d(meta['platform']['frameScale'])
      ..sunDir = [for (final v in meta['sunDir'] as List) d(v)];
    s.setPalette(palette);
    s.invalidTint = s.tintFor(const Color(0xFFE5484D));
    s.cube = await images.load('cube.png');
    s.marker = await images.load('tile_marker.png');
    s.peg = await images.load('peg.png');
    s.platformStill = await images.load('platform_still.png');
    s.platform = [
      for (var i = 0; i < s.frames; i++)
        await images.load('platform_${i.toString().padLeft(3, '0')}.png'),
    ];
    return s;
  }

  /// Wechselt die Blockfarben (kosmetische Freischaltung).
  void setPalette(List<Color> colors) {
    palette = colors;
    tint = [for (final c in colors) tintFor(c)];
    shade = [
      for (final c in colors) Color.lerp(c, const Color(0xFF16202B), 0.2)!,
    ];
  }

  /// Filter, der das graue Würfel-Sprite in [c] einfärbt. Die Kanäle werden
  /// mit Farbwert / Grauwert skaliert (Faktoren über 1 sind erlaubt).
  ColorFilter tintFor(Color c) {
    final r = c.r * 255 / _gray, g = c.g * 255 / _gray, b = c.b * 255 / _gray;
    return ColorFilter.matrix(<double>[
      r, 0, 0, 0, 0, //
      0, g, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Sprite-Frame für einen Drehwinkel in Grad (Würfel/Plattform sind 90°-symmetrisch).
  int frameFor(double deg) {
    final m = deg % 90;
    return (m / angleStepDeg).round() % frames;
  }

  Rect atlasRect(int frame, Size cell) => Rect.fromLTWH(
    (frame % atlasCols) * cell.width,
    (frame ~/ atlasCols) * cell.height,
    cell.width,
    cell.height,
  );
}
