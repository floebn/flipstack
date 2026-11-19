import 'dart:convert';
import 'dart:io';

import 'package:flipstack/game/core/piece.dart';
import 'package:flipstack/shared/theme/fs_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blender-Skripte und App müssen dieselben Farben und Formen verwenden.
void main() {
  final cfg = jsonDecode(
    File('tools/blender/config.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  String hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  test('Blockpalette in App und Blender stimmt überein', () {
    final names = (cfg['block_palette'] as List).cast<String>();
    final colors = cfg['colors'] as Map<String, dynamic>;
    expect(names.length, FsColors.blocks.length);
    for (var i = 0; i < names.length; i++) {
      expect(
        hex(FsColors.blocks[i].toARGB32()),
        colors[names[i]],
        reason: names[i],
      );
    }
  });

  test('jede Form verwendet eine vorhandene Farbe', () {
    for (final s in PieceLibrary.all) {
      expect(
        s.color,
        inInclusiveRange(0, FsColors.blocks.length - 1),
        reason: s.name,
      );
    }
  });

  test('pieces.json für Blender ist aktuell', () {
    final data = jsonDecode(
      File('tools/blender/pieces.json').readAsStringSync(),
    ) as List;
    expect(data.length, PieceLibrary.all.length);
    for (var i = 0; i < data.length; i++) {
      final s = PieceLibrary.all[i];
      expect(data[i]['name'], s.name);
      expect(data[i]['color'], s.color);
      expect(data[i]['cells'], [
        for (final (x, y, z) in s.cells) [x, y, z],
      ]);
    }
  });
}
