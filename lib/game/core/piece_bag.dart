import 'dart:math';

import 'piece.dart';

/// Faire, reproduzierbare Bausteinfolge: Jede Form kommt pro "Beutel" genau
/// einmal vor, die Reihenfolge im Beutel ist zufällig (seedbar).
class PieceBag {
  PieceBag(this.shapes, {int? seed}) : _rng = Random(seed);

  final List<PieceShape> shapes;
  final Random _rng;
  final List<PieceShape> _queue = [];

  PieceShape next() {
    if (_queue.isEmpty) _queue.addAll([...shapes]..shuffle(_rng));
    return _queue.removeLast();
  }
}
