import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import 'settings_store.dart';

/// Preloads the game's short sound effects and plays them with minimal latency.
///
/// Each effect gets a small POOL of preloaded [AudioPlayer]s that are used
/// round-robin, so effects that can fire in quick succession (tap, valid,
/// invalid) overlap cleanly instead of cutting each other off when the player
/// types fast — a single shared player per sound drops rapid repeats. Muted
/// centrally via [SettingsStore.soundEnabled].
class AudioService {
  final SettingsStore settings;
  AudioService(this.settings);

  static const Map<String, String> _files = {
    'tap': 'sfx/tap.wav',
    'valid': 'sfx/valid.wav',
    'invalid': 'sfx/invalid.wav',
    'warn': 'sfx/warn.wav',
    'start': 'sfx/start.wav',
    'end': 'sfx/end.wav',
    'rankup': 'sfx/rankup.wav',
  };

  // How many players to preload per effect. Rapid-fire effects get several so
  // fast typing never runs out of a free (not-currently-playing) player.
  static const Map<String, int> _poolSize = {
    'tap': 6,
    'valid': 3,
    'invalid': 3,
    'warn': 2,
    'start': 1,
    'end': 1,
    'rankup': 1,
  };

  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _cursor = {};
  bool _ready = false;

  // Looping background music. Kept separate from the one-shot SFX pools and
  // played quietly so it sits under them.
  AudioPlayer? _music;
  bool _musicLoaded = false;
  /// Maps the low/med/high music setting to an actual player volume (kept
  /// subtle so even "high" sits under the sound effects).
  static double _volumeFor(AudioLevel l) => switch (l) {
        AudioLevel.low => 0.12,
        AudioLevel.medium => 0.22,
        AudioLevel.high => 0.38,
      };

  /// Maps the low/med/high sound-effects setting to a player volume.
  static double _sfxVolumeFor(AudioLevel l) => switch (l) {
        AudioLevel.low => 0.40,
        AudioLevel.medium => 0.70,
        AudioLevel.high => 1.0,
      };

  /// The soundtrack. `id` is persisted in settings; `name` shows in Settings.
  static const List<({String id, String name, String asset})> musicTracks = [
    (id: 'dark1', name: 'Dark Classical 1', asset: 'music/dark_classical_1.mp3'),
    (id: 'dark2', name: 'Dark Classical 2', asset: 'music/dark_classical_2.mp3'),
    (id: 'irish1', name: 'Irish Theme 1', asset: 'music/irish_1.mp3'),
    (id: 'irish2', name: 'Irish Theme 2', asset: 'music/irish_2.mp3'),
    (id: 'viking1', name: 'Viking Theme 1', asset: 'music/viking_1.mp3'),
    (id: 'viking2', name: 'Viking Theme 2', asset: 'music/viking_2.mp3'),
  ];

  /// Sentinel [SettingsStore.musicTrack] value meaning "rotate through all".
  static const shuffleId = 'shuffle';

  String? _currentAsset; // what's loaded on the music player right now
  int _shuffleIdx = -1; // last shuffle index, to avoid back-to-back repeats

  Future<void> init() async {
    try {
      // Mix, don't interrupt: tell every player NOT to request audio focus so a
      // tap/word blip plays alongside the background music instead of pausing
      // it. On iOS, the ambient category with mixWithOthers does the same.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
    } catch (_) {}
    try {
      for (final e in _files.entries) {
        final n = _poolSize[e.key] ?? 1;
        final players = <AudioPlayer>[];
        for (var i = 0; i < n; i++) {
          final p = AudioPlayer(playerId: 'ws_${e.key}_$i');
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setSource(AssetSource(e.value));
          await p.setVolume(_sfxVolumeFor(settings.soundVolume));
          players.add(p);
        }
        _pools[e.key] = players;
        _cursor[e.key] = 0;
      }
      _ready = true;
    } catch (_) {
      _ready = false; // never let audio setup break app launch
    }
    try {
      final m = AudioPlayer(playerId: 'ws_music');
      await m.setVolume(_volumeFor(settings.musicVolume));
      // When a shuffled track ends, advance to the next one.
      m.onPlayerComplete.listen((_) {
        if (settings.musicEnabled && settings.musicTrack == shuffleId) {
          _playShuffleNext();
        }
      });
      _music = m;
      _musicLoaded = true;
    } catch (_) {
      _musicLoaded = false; // music is optional; never block launch
    }
  }

  // --- background soundtrack ---

  /// Start (or resume) the soundtrack if music is enabled. Safe to call often.
  Future<void> startMusic() async {
    if (!_musicLoaded || !settings.musicEnabled) return;
    try {
      if (_currentAsset == null) {
        await _beginSelection(); // nothing loaded yet — pick per settings
      } else {
        await _music!.resume(); // already loaded (e.g. after a pause)
      }
    } catch (_) {}
  }

  /// Pause playback (position kept), e.g. on background or when toggled off.
  Future<void> pauseMusic() async {
    if (!_musicLoaded) return;
    try {
      await _music!.pause();
    } catch (_) {}
  }

  /// Apply the on/off toggle immediately.
  Future<void> setMusicEnabled(bool on) => on ? startMusic() : pauseMusic();

  /// Resume after returning to the foreground, respecting the setting.
  Future<void> resumeMusicIfEnabled() => startMusic();

  /// Change the music loudness and apply it live.
  Future<void> setMusicVolume(AudioLevel level) async {
    await settings.setMusicVolume(level);
    if (!_musicLoaded) return;
    try {
      await _music!.setVolume(_volumeFor(level));
    } catch (_) {}
  }

  /// Change the active selection (a track id or [shuffleId]) and play it now.
  Future<void> setMusicTrack(String id) async {
    await settings.setMusicTrack(id);
    if (!_musicLoaded || !settings.musicEnabled) return;
    await _beginSelection();
  }

  Future<void> _beginSelection() async {
    if (settings.musicTrack == shuffleId) {
      await _playShuffleNext();
    } else {
      final t = musicTracks.firstWhere(
        (t) => t.id == settings.musicTrack,
        orElse: () => musicTracks.first,
      );
      await _playAsset(t.asset, loop: true);
    }
  }

  Future<void> _playShuffleNext() async {
    if (musicTracks.length > 1) {
      int i;
      do {
        i = _rng.nextInt(musicTracks.length);
      } while (i == _shuffleIdx);
      _shuffleIdx = i;
    } else {
      _shuffleIdx = 0;
    }
    // Each shuffled track plays once then completes so the listener advances.
    await _playAsset(musicTracks[_shuffleIdx].asset, loop: false);
  }

  Future<void> _playAsset(String asset, {required bool loop}) async {
    final m = _music;
    if (m == null) return;
    try {
      await m.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await m.stop();
      await m.setSource(AssetSource(asset));
      _currentAsset = asset;
      await m.resume();
    } catch (_) {}
  }

  final Random _rng = Random();

  void _play(String key) {
    if (!_ready || !settings.soundEnabled) return;
    final players = _pools[key];
    if (players == null || players.isEmpty) return;
    // Advance the ring so each rapid trigger grabs a different player.
    final i = _cursor[key]!;
    _cursor[key] = (i + 1) % players.length;
    final p = players[i];
    // Fire and forget — restart this player from the top. Not awaited so taps
    // stay snappy; failures are swallowed so audio never breaks gameplay.
    p.stop().then((_) => p.resume()).catchError((_) {});
  }

  /// Change sound-effect loudness and apply it to every pooled player live.
  Future<void> setSoundVolume(AudioLevel level) async {
    await settings.setSoundVolume(level);
    final v = _sfxVolumeFor(level);
    for (final players in _pools.values) {
      for (final p in players) {
        try {
          await p.setVolume(v);
        } catch (_) {}
      }
    }
  }

  void tap() => _play('tap');
  void valid() => _play('valid');
  void invalid() => _play('invalid');
  void warn() => _play('warn');
  void start() => _play('start');
  void end() => _play('end');
  void rankup() => _play('rankup');

  Future<void> dispose() async {
    for (final players in _pools.values) {
      for (final p in players) {
        await p.dispose();
      }
    }
    _pools.clear();
    await _music?.dispose();
    _music = null;
  }
}
