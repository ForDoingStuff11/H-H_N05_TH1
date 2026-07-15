import 'package:audioplayers/audioplayers.dart';
import '../models/sound.dart';

class AudioService {
  AudioService._();

  //------------------------
  // Background Music (giữ 1 player, chỉ phát 1 bản nhạc tại 1 thời điểm)
  //------------------------

  static final AudioPlayer _bgmPlayer = AudioPlayer();

  //------------------------
  // Sound Effects (pool xoay vòng để phát chồng lấn được)
  //------------------------

  static const int _sfxPoolSize = 4;
  static final List<AudioPlayer> _sfxPool = List.generate(
    _sfxPoolSize,
    (_) => AudioPlayer(),
  );
  static int _nextSfxIndex = 0;

  static bool musicEnabled = true;
  static bool soundEnabled = true;

  static double _musicVolume = 0.7;
  static double _soundVolume = 1;

  static Future<void> initialize() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      for (final player in _sfxPool) {
        await player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      // Không để lỗi âm thanh ảnh hưởng luồng chính của app
    }
  }

  //------------------------
  // Background Music
  //------------------------

  static Future<void> playBgm(BackgroundMusic music) async {
    if (!musicEnabled) return;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(_musicVolume);
      await _bgmPlayer.play(AssetSource(_bgmPath(music)));
    } catch (e) {
      // Không để lỗi âm thanh ảnh hưởng luồng chính của app
    }
  }

  static Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      // ignore
    }
  }

  //------------------------
  // Sound Effect
  //------------------------

  static Future<void> play(SoundEffect sound) async {
    if (!soundEnabled) return;

    final player = _sfxPool[_nextSfxIndex];
    _nextSfxIndex = (_nextSfxIndex + 1) % _sfxPoolSize;

    try {
      await player.stop();
      await player.setVolume(_soundVolume);
      await player.play(AssetSource(_sfxPath(sound)));
    } catch (e) {
      // Không để lỗi âm thanh ảnh hưởng luồng chính của app
    }
  }

  //------------------------
  // Cleanup
  //------------------------

  static Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
      for (final player in _sfxPool) {
        await player.dispose();
      }
    } catch (e) {
      // ignore
    }
  }

  static Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    await _bgmPlayer.setVolume(volume);
  }

  static Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
  }

  //------------------------
  // Mapping
  //------------------------

  static String _bgmPath(BackgroundMusic music) {
    switch (music) {
      case BackgroundMusic.menu:
        return "audio/bgm/menu.mp3";

      case BackgroundMusic.game:
        return "audio/bgm/game.mp3";
    }
  }

  static String _sfxPath(SoundEffect sound) {
    switch (sound) {
      case SoundEffect.click:
        return "audio/sfx/click.mp3";

      case SoundEffect.place:
        return "audio/sfx/place.mp3";

      case SoundEffect.invite:
        return "audio/sfx/invite.mp3";

      case SoundEffect.accept:
        return "audio/sfx/accept.mp3";

      case SoundEffect.win:
        return "audio/sfx/win.mp3";

      case SoundEffect.lose:
        return "audio/sfx/lose.mp3";

      case SoundEffect.draw:
        return "audio/sfx/draw.mp3";

      case SoundEffect.timeoutWarning:
        return "audio/sfx/timeoutWarning.mp3";
    }
  }
}
