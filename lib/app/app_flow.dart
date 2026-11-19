/// Zustände der App (Masterbrief 10.3). Die feineren Zustände innerhalb einer
/// Runde (Vorschau, Fallen, Drehen) verwaltet `GameSession`.
enum AppState { loading, mainMenu, tutorial, playing, paused, gameOver }

/// Erlaubte Übergänge zwischen den App-Zuständen. Ungültige Übergänge werden
/// abgelehnt und verändern nichts.
class AppFlow {
  AppState _state = AppState.loading;
  AppState? _beforePause;

  AppState get state => _state;

  /// Zustand, zu dem "Weiter" aus der Pause zurückkehrt.
  AppState? get beforePause => _beforePause;

  static const Map<AppState, Set<AppState>> _allowed = {
    AppState.loading: {AppState.mainMenu},
    AppState.mainMenu: {AppState.playing, AppState.tutorial},
    AppState.tutorial: {
      AppState.playing,
      AppState.paused,
      AppState.gameOver,
      AppState.mainMenu,
    },
    AppState.playing: {AppState.paused, AppState.gameOver},
    AppState.paused: {AppState.playing, AppState.tutorial, AppState.mainMenu},
    AppState.gameOver: {AppState.playing, AppState.mainMenu},
  };

  bool canGo(AppState to) => _allowed[_state]!.contains(to);

  /// Wechselt den Zustand; liefert `false`, wenn der Übergang nicht erlaubt ist.
  bool go(AppState to) {
    if (!canGo(to)) return false;
    if (to == AppState.paused) _beforePause = _state;
    // Aus der Pause geht es nur in den Zustand zurück, aus dem sie kam,
    // oder über einen Neustart ins Spiel bzw. ins Hauptmenü.
    _state = to;
    return true;
  }

  /// Pausiert, falls gerade gespielt wird (z. B. wenn die App in den
  /// Hintergrund wechselt).
  bool pauseIfActive() =>
      (_state == AppState.playing || _state == AppState.tutorial) &&
      go(AppState.paused);

  /// Setzt nach der Pause dort fort, wo pausiert wurde.
  bool resume() {
    final back = _beforePause;
    if (_state != AppState.paused || back == null) return false;
    _state = back;
    return true;
  }
}

/// Fortschritt des Tutorials: vier kurze Schritte, die der Spieler durch
/// eigenes Tun abschliesst.
enum TutorialStep { move, drop, rotate, rules, done }

class TutorialProgress {
  TutorialStep step = TutorialStep.move;

  bool get isDone => step == TutorialStep.done;

  /// Meldet eine Spieleraktion; liefert `true`, wenn der Schritt damit endet.
  bool onMoved() => _advance(TutorialStep.move, TutorialStep.drop);
  bool onPlaced() => _advance(TutorialStep.drop, TutorialStep.rotate);
  bool onRotated() => _advance(TutorialStep.rotate, TutorialStep.rules);

  /// Der Spieler bestätigt den letzten Hinweis.
  bool confirmRules() => _advance(TutorialStep.rules, TutorialStep.done);

  void skip() => step = TutorialStep.done;

  bool _advance(TutorialStep from, TutorialStep to) {
    if (step != from) return false;
    step = to;
    return true;
  }
}
