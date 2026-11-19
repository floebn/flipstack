import 'dart:math';

import 'piece.dart';

/// Faire, reproduzierbare Bausteinfolge: Jede Form des aktuellen Vorrats kommt
/// pro "Beutel" so oft vor, wie der Vorrat sie enthält; die Reihenfolge im
/// Beutel ist zufällig (seedbar). Der Vorrat kann mit dem Fortschritt wachsen.
class PieceBag {
  PieceBag(this.pool, {int? seed}) : _rng = Random(seed);

  /// Liefert den Vorrat abhängig von der Anzahl bereits gezogener Bausteine.
  final List<PieceShape> Function(int drawn) pool;
  final Random _rng;
  final List<PieceShape> _queue = [];
  int _drawn = 0;

  PieceShape next() {
    if (_queue.isEmpty) _queue.addAll([...pool(_drawn)]..shuffle(_rng));
    _drawn++;
    return _queue.removeLast();
  }
}
