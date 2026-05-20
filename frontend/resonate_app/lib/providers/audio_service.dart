import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  void Function()? onSongComplete;
  void Function(String error)? onLoadError;

  AudioService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        onSongComplete?.call();
      }
    });
  }

  Future<bool> load(String url) async {
    try {
      await _player.stop();
      await _player.setUrl(url);
      return true;
    } on PlayerException catch (e) {
      onLoadError?.call("Could not load audio: ${e.message}");
      return false;
    } on PlayerInterruptedException {
      // Interrupted by another load
      return false;
    } catch (e) {
      onLoadError?.call("Unexpected error loading audio");
      return false;
    }
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
