import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonate_app/controllers/socket_controller.dart';
import 'package:resonate_app/providers/audioservice_provider.dart';
import 'package:resonate_app/providers/session_notifier.dart';
import 'package:resonate_app/providers/session_state.dart';
import 'package:resonate_app/services/socket_service.dart';
import 'package:resonate_app/services/time_sync_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final s = SocketService();
  ref.onDispose(() => s.disconnect());
  return s;
});

final socketControllerProvider = Provider<SocketController>((ref) {
  final socket = ref.read(socketServiceProvider);
  return SocketController(socket);
});

final timeSyncServiceProvider = Provider<TimeSyncService>((ref) {
  final socket = ref.read(socketServiceProvider);
  final ts = TimeSyncService(socket);
  ts.init();

  
  ref.onDispose(() {
    ts.dispose();
  });

  return ts;
});

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  final socket = ref.read(socketServiceProvider);
  final controller = ref.read(socketControllerProvider);
  final audio = ref.read(audioServiceProvider);
  final timeSync = ref.read(timeSyncServiceProvider);

  return SessionNotifier(controller, socket, audio, timeSync);
});
