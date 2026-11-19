import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/settings_store.dart';

/// Hörbare und fühlbare Rückmeldung zu Spielereignissen.
/// Das Spiel kennt nur diese Schnittstelle.
abstract class GameFeedback {
  void spawn() {}
  void move() {}
  void drop() {}
  void land() {}
  void rotate() {}
  void invalid() {}

  /// [combo] = saubere Ablagen in Folge (ab 2 hörbar).
  void combo(int combo) {}
  void layer() {}
  void milestone() {}
  void highscore() {}
  void gameOver() {}
  void reward() {}
  void tap() {}
}

/// Ohne Wirkung (Tests, Autoplay).
class SilentFeedback extends GameFeedback {}

/// Ton über flame_audio, Vibration über die Plattform. Beides lässt sich in den
/// Einstellungen abschalten. Fehler beim Abspielen stören das Spiel nie.
class DeviceFeedback extends GameFeedback {
  DeviceFeedback(this.settings);

  final Settings settings;
  bool _ready = false;
  AudioPool? _movePool, _landPool;

  static const _files = [
    'spawn.wav',
    'move.wav',
    'drop.wav',
    'land.wav',
    'rotate.wav',
    'invalid.wav',
    'combo_1.wav',
    'combo_2.wav',
    'combo_3.wav',
    'combo_4.wav',
    'combo_5.wav',
    'combo_6.wav',
    'combo_7.wav',
    'combo_8.wav',
    'layer.wav',
    'milestone.wav',
    'highscore.wav',
    'gameover.wav',
    'reward.wav',
    'tap.wav',
  ];

  /// iOS: Kategorie "ambient" beachtet den Stummschalter und lässt Musik
  /// anderer Apps weiterlaufen. Android: Spielklänge ohne Audiofokus, damit
  /// andere Wiedergabe nicht unterbrochen wird.
  static final AudioContext _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Letzter Fehler der Tonausgabe (für die Diagnose; das Spiel läuft weiter).
  Object? lastError;

  bool get isReady => _ready;

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
      await FlameAudio.audioCache.loadAll(_files);
      _movePool = await FlameAudio.createPool(
        'move.wav',
        maxPlayers: 3,
        audioContext: _context,
      );
      _landPool = await FlameAudio.createPool(
        'land.wav',
        maxPlayers: 2,
        audioContext: _context,
      );
      _ready = true;
      debugPrint('FLIPSTACK audio: bereit (${_files.length} Klänge)');
    } catch (e) {
      _fail('init', e);
      _ready = false; // Spiel läuft ohne Ton weiter
    }
  }

  void _fail(String what, Object e) {
    lastError = e;
    debugPrint('FLIPSTACK audio: Fehler bei $what: $e');
  }

  void _play(String file, [double volume = 1]) {
    if (!_ready || !settings.sound) return;
    FlameAudio.play(
      file,
      volume: volume,
      audioContext: _context,
    ).then((_) {}, onError: (Object e) => _fail(file, e));
  }

  void _pool(AudioPool? pool, [double volume = 1]) {
    if (!_ready || !settings.sound || pool == null) return;
    pool
        .start(volume: volume)
        .then((_) {}, onError: (Object e) => _fail('pool', e));
  }

  void _haptic(Future<void> Function() f) {
    if (settings.haptics) f();
  }

  @override
  void spawn() => _play('spawn.wav');

  @override
  void move() {
    _pool(_movePool);
    _haptic(HapticFeedback.selectionClick);
  }

  @override
  void drop() => _play('drop.wav');

  @override
  void land() {
    _pool(_landPool);
    _haptic(HapticFeedback.mediumImpact);
  }

  @override
  void rotate() {
    _play('rotate.wav');
    _haptic(HapticFeedback.selectionClick);
  }

  @override
  void invalid() {
    _play('invalid.wav');
    _haptic(HapticFeedback.heavyImpact);
  }

  @override
  void combo(int combo) {
    if (combo >= 2) _play('combo_${(combo - 1).clamp(1, 8)}.wav');
  }

  @override
  void layer() => _play('layer.wav');

  @override
  void milestone() => _play('milestone.wav');

  @override
  void highscore() => _play('highscore.wav');

  @override
  void gameOver() {
    _play('gameover.wav');
    _haptic(HapticFeedback.heavyImpact);
  }

  @override
  void reward() => _play('reward.wav');

  @override
  void tap() {
    _play('tap.wav');
    _haptic(HapticFeedback.selectionClick);
  }
}
