import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart';

/// In Blender gerenderte Sprites samt Metadaten (assets/sprites/sprites.json).
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
  late final List<Image> cubes;

  /// Abgedunkelte Würfelfarben für die Fugen zwischen Würfeln.
  late final List<Color> cubeShade;
  late final Image marker;

  /// Plattform im Ruhezustand (volle Auflösung).
  late final Image platformStill;

  /// Plattform während der Drehung (um [platformFrameScale] verkleinert).
  late final List<Image> platform;
  late final double platformFrameScale;

  static Future<SpriteSet> load() async {
    final images = Images(prefix: 'assets/sprites/');
    final meta = jsonDecode(
      await rootBundle.loadString('assets/sprites/sprites.json'),
    ) as Map<String, dynamic>;
    final s = SpriteSet._()
      ..ppu = (meta['ppu'] as num).toDouble()
      ..frames = meta['frames'] as int
      ..angleStepDeg = meta['angleStepDeg'] as int
      ..atlasCols = meta['atlasCols'] as int
      ..cubeSize = (meta['cube']['w'] as num).toDouble()
      ..tileSize = Size(
        (meta['tile']['w'] as num).toDouble(),
        (meta['tile']['h'] as num).toDouble(),
      )
      ..tileCenterZ = (meta['tile']['centerZ'] as num).toDouble()
      ..platformTargetZ = (meta['platform']['targetZ'] as num).toDouble()
      ..sunDir = [
        for (final v in meta['sunDir'] as List) (v as num).toDouble(),
      ];
    final colors = (meta['cube']['colors'] as List).cast<String>();
    s.cubeShade = [
      for (final h in (meta['cube']['hex'] as List).cast<String>())
        Color.lerp(
          Color(0xFF000000 | int.parse(h.substring(1), radix: 16)),
          const Color(0xFF16202B),
          0.2,
        )!,
    ];
    s.cubes = [for (final c in colors) await images.load('cube_$c.png')];
    s.marker = await images.load('tile_marker.png');
    s.platformFrameScale = (meta['platform']['frameScale'] as num).toDouble();
    s.platformStill = await images.load('platform_still.png');
    s.platform = [
      for (var i = 0; i < s.frames; i++)
        await images.load('platform_${i.toString().padLeft(3, '0')}.png'),
    ];
    return s;
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
