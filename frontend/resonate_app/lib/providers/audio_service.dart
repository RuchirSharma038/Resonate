import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();


  void Function()? onSongComplete;

  AudioService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {

        onSongComplete?.call();

      }
    });
  }

  Future<void> load(String url) async {
    await _player.stop();
    await _player.setUrl(url);
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  AudioPlayer get player => _player;

  void dispose() {
    _player.dispose();
  }
}