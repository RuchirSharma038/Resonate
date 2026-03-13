import 'package:flutter/material.dart';

import '../services/audio_service.dart';

class AudioController extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  bool isLoaded = false;

  Future<void> loadTrack(String url) async {
    try {
      await _audioService.loadAndPlay(url);
      isLoaded = true;
    } catch (e) {
      isLoaded = false;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> playTrack() async {
    await _audioService.play();
  }

  Future<void> pauseTrack() async {
    await _audioService.pause();
  }

  Future<void> stopTrack() async {
    await _audioService.stop();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
