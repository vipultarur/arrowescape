import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio manager for all game sounds and music.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  String _currentBgTrack = 'smooth_ambient.wav';

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  String get currentBgTrack => _currentBgTrack;

  final List<String> _exitSounds = [
    'swoosh_18.mp3',
  ];
  int _exitSoundIndex = 0;

  late AudioPool _clickPool;
  bool _clickPoolInitialized = false;
  late AudioPool _coinPool;
  bool _coinPoolInitialized = false;
  late AudioPool _levelCompletePool;
  bool _levelCompletePoolInitialized = false;
  final List<AudioPool> _exitPools = [];
  bool _exitPoolsInitialized = false;

  Future<void> initialize() async {
    try {
      FlameAudio.bgm.initialize();
      // Precache the audio files
      await FlameAudio.audioCache.loadAll([
        'click.ogg',
        'underwater.mp3',
        'smooth_ambient.wav',
        'coin_collect.wav',
        'level_complete.wav',
        ..._exitSounds,
      ]);

      // Pre-warm audio pools concurrently to avoid blocking startup
      await Future.wait([
        FlameAudio.createPool('click.ogg', minPlayers: 3, maxPlayers: 5).then((pool) {
          _clickPool = pool;
          _clickPoolInitialized = true;
        }).catchError((e) {
          debugPrint('Error creating click pool: $e');
        }),
        FlameAudio.createPool('coin_collect.wav', minPlayers: 2, maxPlayers: 4).then((pool) {
          _coinPool = pool;
          _coinPoolInitialized = true;
        }).catchError((e) {
          debugPrint('Error creating coin pool: $e');
        }),
        FlameAudio.createPool('level_complete.wav', minPlayers: 1, maxPlayers: 2).then((pool) {
          _levelCompletePool = pool;
          _levelCompletePoolInitialized = true;
        }).catchError((e) {
          debugPrint('Error creating level complete pool: $e');
        }),
        ..._exitSounds.map((sound) => FlameAudio.createPool(sound, minPlayers: 2, maxPlayers: 4).then((pool) {
              _exitPools.add(pool);
            }).catchError((e) {
              debugPrint('Error creating exit pool: $e');
            })),
      ]);
      _exitPoolsInitialized = _exitPools.isNotEmpty;

      if (_musicEnabled) {
        await playBgMusic();
      }
    } catch (e) {
      debugPrint('Error initializing FlameAudio: $e');
    }
  }

  // ── Music ─────────────────────────────────────────────────────────────────────

  Future<void> playBgMusic() async {
    if (!_musicEnabled) return;
    try {
      if (FlameAudio.bgm.isPlaying) return;
      await FlameAudio.bgm.play(_currentBgTrack, volume: 0.35);
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await FlameAudio.bgm.pause();
    } catch (e) {
      debugPrint('Error pausing background music: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_musicEnabled) return;
    try {
      if (!FlameAudio.bgm.isPlaying) {
        await FlameAudio.bgm.resume();
      }
    } catch (_) {
      await playBgMusic();
    }
  }

  Future<void> setBgTrack(String track) async {
    if (_currentBgTrack == track) return;
    _currentBgTrack = track;
    if (_musicEnabled) {
      await stopMusic();
      await playBgMusic();
    }
  }

  Future<void> playMenuMusic() async {
    await playBgMusic();
  }

  Future<void> playGameMusic() async {
    await playBgMusic();
  }

  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  // ── SFX ───────────────────────────────────────────────────────────────────────

  Future<void> playClick() async {
    if (!_soundEnabled) return;
    try {
      if (_clickPoolInitialized) {
        try {
          await _clickPool.start(volume: 0.8);
        } catch (_) {
          await FlameAudio.play('click.ogg', volume: 0.8);
        }
      } else {
        await FlameAudio.play('click.ogg', volume: 0.8);
      }
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  Future<void> playArrowTap() async {
    await playClick();
  }

  Future<void> playArrowExit() async {
    if (!_soundEnabled) return;
    try {
      final poolIndex = _exitSoundIndex;
      _exitSoundIndex = (_exitSoundIndex + 1) % _exitSounds.length;

      if (_exitPoolsInitialized && poolIndex < _exitPools.length) {
        try {
          await _exitPools[poolIndex].start(volume: 0.8);
        } catch (_) {
          await FlameAudio.play(_exitSounds[poolIndex], volume: 0.8);
        }
      } else {
        await FlameAudio.play(_exitSounds[poolIndex], volume: 0.8);
      }
    } catch (e) {
      debugPrint('Error playing arrow exit sound: $e');
    }
  }

  Future<void> playArrowBlock() async {
    // TODO: Implement block sound effect
  }

  Future<void> playCoinCollect() async {
    if (!_soundEnabled) return;
    try {
      if (_coinPoolInitialized) {
        try {
          await _coinPool.start(volume: 0.85);
        } catch (_) {
          await FlameAudio.play('coin_collect.wav', volume: 0.85);
        }
      } else {
        await FlameAudio.play('coin_collect.wav', volume: 0.85);
      }
    } catch (e) {
      debugPrint('Error playing coin collect sound: $e');
    }
  }

  Future<void> playLevelComplete() async {
    if (!_soundEnabled) return;
    try {
      if (_levelCompletePoolInitialized) {
        try {
          await _levelCompletePool.start(volume: 0.9);
        } catch (_) {
          await FlameAudio.play('level_complete.wav', volume: 0.9);
        }
      } else {
        await FlameAudio.play('level_complete.wav', volume: 0.9);
      }
    } catch (e) {
      debugPrint('Error playing level complete sound: $e');
    }
  }

  Future<void> playLifeLost() async {
    // TODO: Implement life lost sound effect
  }

  Future<void> playGameOver() async {
    // TODO: Implement game over sound effect
  }

  Future<void> playStreakExtended() async {
    // TODO: Implement streak extended sound effect
  }

  // ── Settings ──────────────────────────────────────────────────────────────────

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
  }

  void setMusicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      stopMusic();
    } else {
      playBgMusic();
    }
  }

  void dispose() {
    try {
      FlameAudio.bgm.dispose();
    } catch (e) {
      debugPrint('Error disposing FlameAudio bgm: $e');
    }
  }
}
