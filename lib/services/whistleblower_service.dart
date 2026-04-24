import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class WhistleblowerService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playAlarm() async {
    try {
      // Pastikan ada file assets/audio/whistle.mp3 di proyek
      await _player.play(AssetSource('audio/whistle.mp3'));
      
      // Getar jika perangkat mendukung
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
      }
    } catch (e) {
      print('[WhistleblowerService] Error playing alarm: $e');
    }
  }

  static Future<void> stopAlarm() async {
    try {
      await _player.stop();
      Vibration.cancel();
    } catch (e) {
      print('[WhistleblowerService] Error stopping alarm: $e');
    }
  }
}
