import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../services/socket_service.dart";

// 1. THIS IS THE MISSING PROVIDER (Defined outside the class)
final socketControllerProvider = Provider<SocketController>((ref) {
  // We get the SocketService from another provider if you have one,
  // or instantiate it directly as your project was doing.
  final service = SocketService();
  return SocketController(service);
});

class SocketController {
  final SocketService socketService;

  int _commandSeq = 0;
  int _nextSeq() => ++_commandSeq;

  SocketController(this.socketService);

  Future<void> init() async {
    socketService.connect();
    // (The queue listener that used 'ref' was safely moved to your SessionNotifier!)
  }

  void createSession() {
    socketService.emit("create_session", {});
  }

  void joinSession(String sessionId) {
    socketService.emit("join_session", {"sessionId": sessionId});
  }

  void leaveSession(String sessionId) {
    socketService.emit("leave_session", {"sessionId": sessionId});
  }

  void setUrl(String sessionId, String url) {
    socketService.emit("set_url", {
      "sessionId": sessionId,
      "url": url,
      "seq": _nextSeq(),
    });
  }

  void playSong(String sessionId) {
    socketService.emit("play", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void pause(String sessionId) {
    socketService.emit("pause", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void stop(String sessionId) {
    socketService.emit("stop", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void addToQueue(String sessionId, String url) {
    socketService.emit("add_to_queue", {
      "sessionId": sessionId,
      "url": url,
    });
  }

  void playNext(String sessionId) {
    socketService.emit("play_next", {
      "sessionId": sessionId,
      "seq": _nextSeq(),
    });
  }

  // Updated logic to ensure the server removes the item from the list
  void removeFromQueue(String sessionId, String url) {
    socketService.emit('remove_from_queue', {
      'sessionId': sessionId,
      'url': url,
    });
  }
}