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
    // Vom Auftraggeber vorgegebene Paletten (Reihenfolge wie angegeben).
    'blocks_sunset': [
      Color(0xFFE97855),
      Color(0xFFF49A65),
      Color(0xFFF6BE68),
      Color(0xFFF5D9B5),
      Color(0xFFC85F55),
      Color(0xFFA94F59),
      Color(0xFFD58B79),
      Color(0xFFE8B99B),
    ],
    'blocks_lagoon': [
      Color(0xFF16B9AD),
      Color(0xFF39AFC4),
      Color(0xFF4389A8),
      Color(0xFFCDE5DF),
      Color(0xFF087F83),
      Color(0xFF386B83),
      Color(0xFF83C8B2),
      Color(0xFFE5B6A2),
    ],
    'blocks_lavender': [
      Color(0xFF927CC8),
      Color(0xFFB29BD9),
      Color(0xFFD6C6ED),
      Color(0xFFF0D7E5),
      Color(0xFF686BA5),
      Color(0xFFB77EAE),
      Color(0xFFA5B9D9),
      Color(0xFFE9B9B4),
    ],
    'blocks_volcano': [
      Color(0xFFE85D45),
      Color(0xFFF28A4B),
      Color(0xFFF3B84B),
      Color(0xFFD8C3A5),
      Color(0xFFA83D38),
      Color(0xFF713E42),
      Color(0xFFC97865),
      Color(0xFF424D5A),
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
    'mat_concrete': ('cube_concrete.png', null),
    'mat_fabric': ('cube_fabric.png', null),
    'mat_volcano': ('cube_volcano.png', null),
    'mat_neon': ('cube_neon.png', 'cube_neon_gloss.png'),
  };

  /// Rücksprung der Kanten in Würfelkanten (entspricht der Fase im
  /// Blender-Skript). Nur für Materialien mit stark gebrochenen Kanten.
  static const edgeInsets = <String, double>{
    'mat_pebble': 0.23,
    'mat_facet': 0.17,
    'mat_fabric': 0.12,
  };

  /// Wie stark die Fugenfüllung gegenüber der Blockfarbe abgedunkelt wird
  /// (Standard 0,2). Materialien mit dunklen Flächen brauchen dunkle Fugen.
  static const seamDarken = <String, double>{
    'mat_volcano': 0.6,
    'mat_neon': 0.6,
  };

  static (String, String?) material(String id) =>
      materials[id] ?? materials['mat_matte']!;

  static const backgrounds = <String, BackgroundTheme>{
    'bg_sand': BackgroundTheme.sand,
    'bg_dawn': BackgroundTheme.dawn,
    'bg_mist': BackgroundTheme.mist,
    'bg_dusk': BackgroundTheme.dusk,
    'bg_forest': BackgroundTheme.forest,
    'bg_autumn': BackgroundTheme.autumn,
    'bg_winter': BackgroundTheme.winter,
    'bg_space': BackgroundTheme.space,
    'bg_underwater': BackgroundTheme.underwater,
    'bg_city': BackgroundTheme.city,
  };

  /// Umfärbung der Plattform als (Faktor, Versatz) je Farbkanal. Der Versatz
  /// wirkt vor allem auf den dunklen Sockel, die hellen Felder bleiben hell.
  static const _platforms = <String, List<(double, double)>>{
    'platform_clay': [(0.84, 46), (0.92, 12), (0.94, 0)],
    'platform_moss': [(0.93, 6), (0.88, 30), (0.90, 2)],
  };

  /// Plattformen mit eigenem Sprite-Satz (tools/blender/render_platforms.py).
  /// Alle anderen nutzen die Standardplattform, gegebenenfalls umgefärbt.
  static const platformSets = <String, String>{
    'platform_oak': 'oak',
    'platform_marble': 'marble',
    'platform_glacier': 'glacier',
    'platform_island': 'island',
    'platform_future': 'future',
  };

  /// Vorschaubild einer Plattform für den Shop.
  static String platformPreview(String id) =>
      'assets/ui/plat_${id.substring('platform_'.length)}.png';

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
