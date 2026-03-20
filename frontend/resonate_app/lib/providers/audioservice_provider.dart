import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});
