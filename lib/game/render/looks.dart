import 'dart:ui';

import '../../shared/theme/fs_colors.dart';
import 'background.dart';

/// Aussehen der kosmetischen Freischaltungen (Kennungen siehe
/// `Cosmetics` in game/meta/rewards.dart). Unbekannte Kennungen fallen auf
/// den Standard zurück.
abstract final class Looks {
  /// Blockpaletten: je acht Farben in derselben Reihenfolge der Farbtöne wie
  /// die Klassik-Palette (grün-blau, rot, gelb, hell, blau, violett, grün, rosa),
  /// damit jede Form in jeder Palette wiedererkennbar bleibt.
  static const palettes = <String, List<Color>>{
    'blocks_classic': FsColors.blocks,
    'blocks_arctic': [
      Color(0xFF4FC4C0),
      Color(0xFFF29E94),
      Color(0xFFF2DA84),
      Color(0xFFD6DFE8),
      Color(0xFF6C9FE0),
      Color(0xFF9A7FD0),
      Color(0xFF8ED1A6),
      Color(0xFFE4A2CC),
    ],
    'blocks_forest': [
      Color(0xFF3F9272),
      Color(0xFFCB6444),
      Color(0xFFDBA945),
      Color(0xFFE2D8C0),
      Color(0xFF5A88AC),
      Color(0xFF80639A),
      Color(0xFF95B254),
      Color(0xFFCB8794),
    ],
    'blocks_candy': [
      Color(0xFF22CBB0),
      Color(0xFFFA6C5C),
      Color(0xFFFCC844),
      Color(0xFFF1EBDD),
      Color(0xFF45A8F0),
      Color(0xFFA070EC),
      Color(0xFF80D65C),
      Color(0xFFFA80B4),
    ],
  };

  /// Block-Materialien: grauer Würfel-Atlas in assets/sprites/ und, falls
  /// vorhanden, ein Glanz-Atlas, der uneingefärbt darüber liegt.
  static const materials = <String, (String, String?)>{
    'mat_matte': ('cube.png', null),
    'mat_pebble': ('cube_pebble.png', null),
    'mat_plank': ('cube_plank.png', null),
    'mat_facet': ('cube_facet.png', null),
    'mat_ice': ('cube_ice.png', 'cube_ice_gloss.png'),
    'mat_stud': ('cube_stud.png', null),
  };

  /// Rücksprung der Kanten in Würfelkanten (entspricht der Fase im
  /// Blender-Skript). Nur für Materialien mit stark gebrochenen Kanten.
  static const edgeInsets = <String, double>{
    'mat_pebble': 0.23,
    'mat_facet': 0.17,
  };

  static (String, String?) material(String id) =>
      materials[id] ?? materials['mat_matte']!;

  static const backgrounds = <String, BackgroundTheme>{
    'bg_sand': BackgroundTheme.sand,
    'bg_dawn': BackgroundTheme.dawn,
    'bg_mist': BackgroundTheme.mist,
    'bg_dusk': BackgroundTheme.dusk,
  };

  /// Umfärbung der Plattform als (Faktor, Versatz) je Farbkanal. Der Versatz
  /// wirkt vor allem auf den dunklen Sockel, die hellen Felder bleiben hell.
  static const _platforms = <String, List<(double, double)>>{
    'platform_clay': [(0.84, 46), (0.92, 12), (0.94, 0)],
    'platform_moss': [(0.93, 6), (0.88, 30), (0.90, 2)],
  };

  /// Sockelfarbe für die Vorschau im Shop.
  static const platformSwatches = <String, Color>{
    'platform_slate': FsColors.navy,
    'platform_clay': Color(0xFF4A3435),
    'platform_moss': Color(0xFF244438),
  };

  static List<Color> palette(String id) => palettes[id] ?? FsColors.blocks;

  static BackgroundTheme background(String id) =>
      backgrounds[id] ?? BackgroundTheme.sand;

  /// Farbfilter für die Plattform oder `null` für das Original.
  static ColorFilter? platformFilter(String id) {
    final m = _platforms[id];
    if (m == null) return null;
    return ColorFilter.matrix(<double>[
      m[0].$1, 0, 0, 0, m[0].$2, //
      0, m[1].$1, 0, 0, m[1].$2, //
      0, 0, m[2].$1, 0, m[2].$2, //
      0, 0, 0, 1, 0, //
    ]);
  }
}
