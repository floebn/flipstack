// ignore_for_file: avoid_print
// Schreibt die Bausteinformen für die Blender-Skripte nach tools/blender/pieces.json.
// Die Dart-Bibliothek ist die einzige Quelle; nach Änderungen an den Formen:
//   dart run tool/export_pieces.dart
import 'dart:convert';
import 'dart:io';

import 'package:flipstack/game/core/piece.dart';

void main() {
  final data = [
    for (final s in PieceLibrary.all)
      {
        'name': s.name,
        'color': s.color,
        'cells': [
          for (final (x, y, z) in s.cells) [x, y, z],
        ],
      },
  ];
  File(
    'tools/blender/pieces.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  print('pieces.json: ${data.length} Formen');
}
