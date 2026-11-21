import 'dart:math';

import 'piece.dart';

/// Faire, reproduzierbare Bausteinfolge: Jede Form des aktuellen Vorrats kommt
/// pro "Beutel" so oft vor, wie der Vorrat sie enthält; die Reihenfolge im
/// Beutel ist zufällig. Der Vorrat kann mit dem Fortschritt wachsen.
///
/// Jeder Beutel wird aus (Startwert, Nummer des Beutels) gemischt. Dadurch
/// lässt sich der Zustand speichern und eine Runde nach dem Schliessen der
/// App mit genau derselben Folge fortsetzen.
class PieceBag {
  PieceBag(this.pool, {int? seed}) : seed = seed ?? Random().nextInt(1 << 31);

  /// Liefert den Vorrat abhängig von der Anzahl bereits gezogener Bausteine.
  final List<PieceShape> Function(int drawn) pool;
  final int seed;
  final List<PieceShape> _queue = [];
  int _drawn = 0;
  int _bags = 0;

  PieceShape next() {
    if (_queue.isEmpty) {
      final rng = Random((seed * 1000003 + _bags) & 0x7fffffff);
      _bags++;
      _queue.addAll([...pool(_drawn)]..shuffle(rng));
    }
    _drawn++;
    return _queue.removeLast();
  }

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'drawn': _drawn,
    'bags': _bags,
    'queue': [for (final s in _queue) s.name],
  };

  /// Stellt den Zustand aus [toJson] wieder her. Unbekannte Formen werden
  /// übergangen.
  void restore(Map<String, dynamic> j) {
    _drawn = j['drawn'] is int ? j['drawn'] as int : 0;
    _bags = j['bags'] is int ? j['bags'] as int : 0;
    _queue
      ..clear()
      ..addAll([
        if (j['queue'] is List)
          for (final n in j['queue'] as List)
            if (PieceLibrary.byName[n] != null) PieceLibrary.byName[n]!,
      ]);
  }
}
