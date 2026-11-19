import 'package:flipstack/app/app_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFlow', () {
    test('startet im Laden und geht nur ins Hauptmenü', () {
      final f = AppFlow();
      expect(f.state, AppState.loading);
      expect(f.go(AppState.playing), isFalse);
      expect(f.state, AppState.loading);
      expect(f.go(AppState.mainMenu), isTrue);
    });

    test('normale Runde: Menü, Spiel, Ergebnis, nochmal, Menü', () {
      final f = AppFlow()..go(AppState.mainMenu);
      expect(f.go(AppState.playing), isTrue);
      expect(f.go(AppState.gameOver), isTrue);
      expect(f.go(AppState.playing), isTrue);
      expect(f.go(AppState.gameOver), isTrue);
      expect(f.go(AppState.mainMenu), isTrue);
    });

    test('ungültige Übergänge werden abgelehnt', () {
      final f = AppFlow()..go(AppState.mainMenu);
      expect(f.go(AppState.gameOver), isFalse);
      expect(f.go(AppState.paused), isFalse);
      f.go(AppState.playing);
      expect(
        f.go(AppState.mainMenu),
        isFalse,
        reason: 'nur über Pause oder Ergebnis',
      );
      expect(f.go(AppState.tutorial), isFalse);
      expect(f.state, AppState.playing);
    });

    test('Pause setzt dort fort, wo pausiert wurde', () {
      final f = AppFlow()
        ..go(AppState.mainMenu)
        ..go(AppState.playing);
      expect(f.go(AppState.paused), isTrue);
      expect(f.resume(), isTrue);
      expect(f.state, AppState.playing);

      final t = AppFlow()
        ..go(AppState.mainMenu)
        ..go(AppState.tutorial)
        ..go(AppState.paused);
      expect(t.resume(), isTrue);
      expect(t.state, AppState.tutorial);
      expect(t.resume(), isFalse, reason: 'nicht pausiert');
    });

    test('App-Wechsel pausiert nur eine laufende Runde', () {
      final f = AppFlow()..go(AppState.mainMenu);
      expect(f.pauseIfActive(), isFalse);
      f.go(AppState.playing);
      expect(f.pauseIfActive(), isTrue);
      expect(f.state, AppState.paused);
      expect(f.pauseIfActive(), isFalse, reason: 'schon pausiert');
      f.resume();
      f.go(AppState.gameOver);
      expect(f.pauseIfActive(), isFalse);
    });

    test('aus der Pause: neu starten oder ins Menü', () {
      final f = AppFlow()
        ..go(AppState.mainMenu)
        ..go(AppState.playing)
        ..go(AppState.paused);
      expect(f.go(AppState.playing), isTrue);
      f.go(AppState.paused);
      expect(f.go(AppState.mainMenu), isTrue);
    });
  });

  group('TutorialProgress', () {
    test(
      'Schritte enden nur durch die passende Aktion, in fester Reihenfolge',
      () {
        final t = TutorialProgress();
        expect(t.onPlaced(), isFalse);
        expect(t.onRotated(), isFalse);
        expect(t.step, TutorialStep.move);
        expect(t.onMoved(), isTrue);
        expect(t.onMoved(), isFalse);
        expect(t.onRotated(), isFalse);
        expect(t.onPlaced(), isTrue);
        expect(t.onRotated(), isTrue);
        expect(t.step, TutorialStep.rules);
        expect(t.isDone, isFalse);
        expect(t.confirmRules(), isTrue);
        expect(t.isDone, isTrue);
      },
    );

    test('Überspringen beendet das Tutorial sofort', () {
      final t = TutorialProgress()..skip();
      expect(t.isDone, isTrue);
      expect(t.onMoved(), isFalse);
    });
  });
}
