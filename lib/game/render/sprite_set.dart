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
  late double platformTargetZ;
  late final double _defaultTargetZ;

  /// Bildmitte je freischaltbarer Plattform (assets/sprites/platforms.json).
  late final Map<String, double> _platformTargetZ;
  String? _platformSet;
  int _platformRequest = 0;
  late final List<double> sunDir;

  /// Grauer Würfel, Atlas über die Drehwinkel. Wechselt mit dem Material.
  late Image cube;

  /// Wie weit die Kanten des Materials gegenüber dem vollen Würfel
  /// zurückspringen (0 = kantig). Steuert die Fugenfüllung.
  double edgeInset = 0;

  /// Glanzlichter des Materials (uneingefärbt über dem Würfel) oder `null`.
  Image? gloss;

  late final Images _images;
  String _cubeFile = 'cube.png';
  String? _glossFile;
  int _materialRequest = 0;

  /// Wechselt das Block-Material. Geladen wird nur der gewählte Atlas, der
  /// vorherige wird freigegeben (ausser dem Standardwürfel).
  Future<void> setMaterial(
    String cubeFile,
    String? glossFile, {
    double edgeInset = 0,
  }) async {
    if (cubeFile == _cubeFile && glossFile == _glossFile) return;
    final request = ++_materialRequest;
    final newCube = await _images.load(cubeFile);
    final newGloss = glossFile == null ? null : await _images.load(glossFile);
    if (request != _materialRequest) return; // inzwischen neu gewählt
    final old = [_cubeFile, ?_glossFile];
    cube = newCube;
    this.edgeInset = edgeInset;
    gloss = newGloss;
    _cubeFile = cubeFile;
    _glossFile = glossFile;
    for (final f in old) {
      if (f != 'cube.png' && f != cubeFile && f != glossFile) _images.clear(f);
    }
  }

  late final Image marker;

  /// Eckpfosten (drehsymmetrisch).
  late final Image peg;
  late final double pegCenterZ;
  late final double pegOffset;

  /// Plattform im Ruhezustand (volle Auflösung).
  late Image platformStill;

  /// Plattform während der Drehung (um [platformFrameScale] verkleinert).
  late List<Image> platform;
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
      .._images = images
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
    s._defaultTargetZ = s.platformTargetZ;
    final sets = jsonDecode(
      await rootBundle.loadString('assets/sprites/platforms.json'),
    ) as Map<String, dynamic>;
    s._platformTargetZ = {
      for (final e in sets.entries) e.key: d((e.value as Map)['targetZ']),
    };
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

  static String _frameFile(String? set, int i) =>
      'platform_${set == null ? '' : '${set}_'}${i.toString().padLeft(3, '0')}.png';

  static String _stillFile(String? set) =>
      'platform_${set == null ? '' : '${set}_'}still.png';

  /// Wechselt den Sprite-Satz der Plattform ([set] = `null` für die
  /// Standardplattform). Geladen ist immer nur ein Satz; der vorherige wird
  /// freigegeben.
  Future<void> setPlatform(String? set) async {
    if (set == _platformSet) return;
    final request = ++_platformRequest;
    final still = await _images.load(_stillFile(set));
    final rotating = [
      for (var i = 0; i < frames; i++) await _images.load(_frameFile(set, i)),
    ];
    if (request != _platformRequest) return; // inzwischen neu gewählt
    final old = _platformSet;
    platformStill = still;
    platform = rotating;
    platformTargetZ = set == null
        ? _defaultTargetZ
        : _platformTargetZ[set] ?? _defaultTargetZ;
    _platformSet = set;
    _images.clear(_stillFile(old));
    for (var i = 0; i < frames; i++) {
      _images.clear(_frameFile(old, i));
    }
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
