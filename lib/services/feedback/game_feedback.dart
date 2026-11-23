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

  /// Je Klang eine feste Zahl vorbereiteter Player, die reihum verwendet
  /// werden. So entstehen während des Spiels keine neuen Player; früher kam
  /// mit jedem Ton einer dazu, der nie freigegeben wurde.
  final Map<String, List<AudioPlayer>> _voices = {};
  final Map<String, int> _nextVoice = {};

  /// Zu Ende gespielte Klänge (Diagnose: zeigt, dass wirklich abgespielt wird).
  int _completed = 0;

  /// Klänge, die sich überlappen können, bekommen mehrere Stimmen.
  static const _voiceCount = {
    'move.wav': 3,
    'land.wav': 2,
    'rotate.wav': 2,
    'tap.wav': 2,
  };

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
      for (final file in _files) {
        _voices[file] = [
          for (var i = 0; i < (_voiceCount[file] ?? 1); i++)
            await _createVoice(file),
        ];
      }
      _ready = true;
      debugPrint('FLIPSTACK audio: bereit (${_files.length} Klänge)');
      const stress = int.fromEnvironment('FS_AUDIO_STRESS');
      for (var i = 0; i < stress; i++) {
        _play(_files[i % _files.length]);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (i % 100 == 0) {
          debugPrint(
            'FLIPSTACK audio: Belastung $i, $_completed zu Ende gespielt',
          );
        }
      }
    } catch (e) {
      _fail('init', e);
      _ready = false; // Spiel läuft ohne Ton weiter
    }
  }

  void _fail(String what, Object e) {
    lastError = e;
    debugPrint('FLIPSTACK audio: Fehler bei $what: $e');
  }

  Future<AudioPlayer> _createVoice(String file) async {
    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(file));
    player.onPlayerComplete.listen((_) => _completed++);
    return player;
  }

  void _play(String file) {
    if (!_ready || !settings.sound) return;
    final voices = _voices[file];
    if (voices == null || voices.isEmpty) return;
    final i = _nextVoice[file] ?? 0;
    _nextVoice[file] = (i + 1) % voices.length;
    final player = voices[i];
    // stop() setzt an den Anfang zurück, auch wenn der Klang noch läuft.
    player
        .stop()
        .then((_) => player.resume())
        .then((_) {}, onError: (Object e) => _fail(file, e));
  }

  void _haptic(Future<void> Function() f) {
    if (settings.haptics) f();
  }

  @override
  void spawn() => _play('spawn.wav');

  @override
  void move() {
    _play('move.wav');
    _haptic(HapticFeedback.selectionClick);
  }

  @override
  void drop() => _play('drop.wav');

  @override
  void land() {
    _play('land.wav');
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
  void layer() {
    _play('layer.wav');
    _haptic(HapticFeedback.heavyImpact);
  }

  @override
  void milestone() {
    _play('milestone.wav');
    _haptic(HapticFeedback.heavyImpact);
  }

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
